ARG RUST_VERSION=1.86.0
FROM rust:${RUST_VERSION}-slim-bookworm AS build

WORKDIR /agave

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && apt-get install -y \
    build-essential \
    pkg-config \
    wget \
    curl \
    libudev-dev \
    llvm \
    libclang-dev \
    protobuf-compiler \
    libssl-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

ARG AGAVE_VERSION=v3.0.8
ARG AGAVE_REPO=anza-xyz/agave

# clone repository and checkout specific version
RUN git init && \
    git remote add origin https://github.com/${AGAVE_REPO}.git && \
    git fetch \
        --no-tags \
        --prune \
        --progress \
        --no-recurse-submodules \
        --depth=1 \
        origin \
        +refs/heads/${AGAVE_VERSION}*:refs/remotes/origin/${AGAVE_VERSION}* \
        +refs/tags/${AGAVE_VERSION}*:refs/tags/${AGAVE_VERSION}* && \
    git checkout --progress --force refs/tags/${AGAVE_VERSION} && \
    git submodule sync --recursive && \
    git submodule update --init --force --depth=1 --recursive

# build all binaries
RUN ./scripts/cargo-install-all.sh --validator-only .

# create a minimal base image
FROM debian:bookworm-slim

RUN apt-get update -y && apt-get install -y \
    ca-certificates \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /agave/bin/ /usr/local/bin/

ENTRYPOINT ["agave-validator"]
