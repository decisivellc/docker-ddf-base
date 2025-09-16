# Set the base name for the image
IMAGE_NAME := codice/ddf-base
GIT_SHA := $(shell git rev-parse HEAD)
MASTER_SHA := $(shell git show-ref -s refs/heads/master)
IMAGE_VERSION := 3.0

# Multi-architecture support
PLATFORMS := linux/amd64,linux/arm64
BUILDER_NAME := ddf-multiarch

# Compute Build Tags
BUILD_TAG := $(IMAGE_NAME):$(IMAGE_VERSION)
LATEST_TAG := $(IMAGE_NAME):latest

.DEFAULT_GOAL := help

.PHONY: help
help: ## Display help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: setup-buildx
setup-buildx: ## Set up Docker Buildx for multi-architecture builds
	@echo "Setting up Docker Buildx..."
	@docker buildx inspect $(BUILDER_NAME) >/dev/null 2>&1 || \
		docker buildx create --name $(BUILDER_NAME) --driver docker-container --bootstrap
	@docker buildx use $(BUILDER_NAME)
	@echo "✅ Buildx builder '$(BUILDER_NAME)' ready"

.PHONY: image
image: ## Build the docker image (single architecture)
	@echo "Building $(BUILD_TAG) for current architecture"
	@docker build --pull -t $(BUILD_TAG) src/main/docker/.

.PHONY: image-multiarch
image-multiarch: setup-buildx ## Build multi-architecture docker images
	@echo "Building $(BUILD_TAG) for platforms: $(PLATFORMS)"
	@docker buildx build \
		--platform $(PLATFORMS) \
		--pull \
		--tag $(BUILD_TAG) \
		--tag $(LATEST_TAG) \
		src/main/docker/.

.PHONY: push
push: image ## Push single-architecture docker image
	@echo "Pushing $(BUILD_TAG)"
	@docker push $(BUILD_TAG)

.PHONY: push-multiarch
push-multiarch: setup-buildx ## Build and push multi-architecture docker images
	@echo "Building and pushing $(BUILD_TAG) for platforms: $(PLATFORMS)"
	@docker buildx build \
		--platform $(PLATFORMS) \
		--pull \
		--push \
		--tag $(BUILD_TAG) \
		--tag $(LATEST_TAG) \
		src/main/docker/.

.PHONY: push-latest
push-latest: ## Tag and push as latest (single arch)
	@docker tag $(BUILD_TAG) $(LATEST_TAG)
	@docker push $(LATEST_TAG)

.PHONY: inspect
inspect: ## Inspect the multi-architecture image manifest
	@echo "Inspecting $(BUILD_TAG) manifest:"
	@docker buildx imagetools inspect $(BUILD_TAG)

.PHONY: clean
clean: ## Clean up build resources
	@echo "Cleaning up Docker build resources..."
	@docker buildx prune -f
	@docker system prune -f

.PHONY: clean-builder
clean-builder: ## Remove the buildx builder
	@echo "Removing buildx builder: $(BUILDER_NAME)"
	@docker buildx rm $(BUILDER_NAME) || true

# Development targets
.PHONY: dev-build
dev-build: image ## Alias for single-arch build (development)

.PHONY: prod-build
prod-build: push-multiarch ## Build and push multi-arch (production)

# Test targets
.PHONY: test-amd64
test-amd64: ## Test AMD64 image
	@echo "Testing AMD64 image..."
	@docker run --rm --platform linux/amd64 $(BUILD_TAG) echo "✅ AMD64 test passed"

.PHONY: test-arm64
test-arm64: ## Test ARM64 image
	@echo "Testing ARM64 image..."
	@docker run --rm --platform linux/arm64 $(BUILD_TAG) echo "✅ ARM64 test passed"

.PHONY: test-all
test-all: push-multiarch test-amd64 test-arm64 ## Test both architectures

# Information targets
.PHONY: info
info: ## Show build information
	@echo "Image Name: $(IMAGE_NAME)"
	@echo "Version: $(IMAGE_VERSION)"
	@echo "Build Tag: $(BUILD_TAG)"
	@echo "Latest Tag: $(LATEST_TAG)"
	@echo "Platforms: $(PLATFORMS)"
	@echo "Git SHA: $(GIT_SHA)"
	@echo "Builder: $(BUILDER_NAME)"

.PHONY: platforms
platforms: ## List supported platforms
	@echo "Supported platforms: $(PLATFORMS)"
	@echo "Available buildx platforms:"
	@docker buildx ls
