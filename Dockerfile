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

ARG PATCH_SHA256_POH
ENV PATCH_SHA256_POH=${PATCH_SHA256_POH}
# use patched sha256 hasher
RUN if [ "${PATCH_SHA256_POH}" = "true" ]; then \
        git clone https://github.com/kagren/solana-sha256-hasher-optimized optimized_sha256 && \
        sed -i '/^members = \[$/a\    "optimized_sha256",' Cargo.toml && \
        sed -i '/^\[dependencies\]$/a optimized_sha256 = { path = "../optimized_sha256", package = "solana-sha256-hasher" }' entry/Cargo.toml && \
        sed -i 's|hashv(&\[self.hash.as_ref(), mixin.as_ref()\])|optimized_sha256::hashv(\&[self.hash.as_ref(), mixin.as_ref()])|' entry/src/poh.rs; \
    fi

# build all binaries
ARG RUST_TARGET_CPU
ENV RUST_TARGET_CPU=${RUST_TARGET_CPU}
RUN if [ "${RUST_TARGET_CPU}" != "" ]; then \
        export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_RUSTFLAGS="-C target-cpu=${RUST_TARGET_CPU}"; \
        export CARGO_BUILD_TARGET="x86_64-unknown-linux-gnu"; \
        sed -i "s|buildProfile='release'|buildProfile='${CARGO_BUILD_TARGET}/release'|g" scripts/cargo-install-all.sh; \
    fi && \
    ./scripts/cargo-install-all.sh --validator-only --no-spl-token .

# create a minimal base image
FROM debian:bookworm-slim

RUN apt-get update -y && apt-get install -y \
    ca-certificates \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /agave/bin/ /usr/local/bin/

ENTRYPOINT ["agave-validator"]
