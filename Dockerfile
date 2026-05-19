# Image refs are pinned by digest for reproducible builds.
# Override JAVA_BASE at build time to produce JDK-specific variants
# (default: JDK 17 for the 2.30.x / Alliance 1.17.x train; pass JDK 21 base for the 2.31+ train).
ARG ARGBASH_IMAGE=matejak/argbash:2.7.1-1@sha256:37e6805e02a940229073654ba3249cfb92392a465c3d9b329008926ad0133e3f
ARG JAVA_BASE=azul/zulu-openjdk-alpine:17.0.19-17.66@sha256:7710ea650d0d685d6c9525c21ea89c37cf820393ab54bcc0eedbe5cbb85a09d8

# Generate commands from argbash templates
FROM --platform=$BUILDPLATFORM ${ARGBASH_IMAGE} AS argbash
# Copy all templates including vendored create-cdm.m4 (eliminates external dependency)
COPY argbash-templates/* /work/
RUN ./build.sh

# Create base for final image.
FROM ${JAVA_BASE} AS base
LABEL maintainer=codice
LABEL org.codice.application.type=ddf

ENV ENTRYPOINT_HOME=/opt/entrypoint

RUN mkdir -p $ENTRYPOINT_HOME

# Install Alpine packages (jq now from Alpine repos for multi-arch support)
RUN apk add --no-cache curl openssl gettext bash jq

# Install props tool with multi-architecture support from codice/props fork
ARG TARGETARCH
ARG PROPS_VERSION=0.1.1
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) PROPS_ARCH='amd64' ;; \
        arm64) PROPS_ARCH='arm64' ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac; \
    echo "Installing props v${PROPS_VERSION} for ${TARGETARCH}"; \
    curl -fsSL "https://github.com/codice/props/releases/download/v${PROPS_VERSION}/props_${PROPS_VERSION}_linux_${PROPS_ARCH}" \
        -o /usr/local/bin/props; \
    chmod 755 /usr/local/bin/props; \
    props version || props help

COPY entrypoint/* $ENTRYPOINT_HOME/
COPY --from=argbash /out/cmd/* /usr/local/bin/

## Create test base
#FROM base as test
#RUN apk add --no-cache git
#RUN git clone https://github.com/bats-core/bats-core.git
#RUN ./bats-core/install.sh /usr/local
#
## Run unit level tests
#FROM test as unit-test
#COPY ./argbash-templates/tests/* /tests/
#RUN bats /tests/*.bats
#
## Run integration level tests
#FROM test as integration-test
#COPY ./tests/* /tests/
#RUN bats /tests/*.bats
#
## Create final image
#FROM base

ENTRYPOINT ["/bin/bash", "-c", "$ENTRYPOINT_HOME/entrypoint.sh"]
