ARG RUST_VERSION=1.86.0
FROM rust:${RUST_VERSION}-slim-bookworm AS build

WORKDIR /agave

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && apt-get install -y \
    build-essential \
    pkg-config \
    wget \
    libudev-dev \
    llvm \
    libclang-dev \
    protobuf-compiler \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

ARG AGAVE_VERSION=v3.0.8
ARG AGAVE_REPO=anza-xyz/agave
ENV AGAVE_DOWNLOAD_URL=https://github.com/${AGAVE_REPO}/archive/refs/tags/${AGAVE_VERSION}.tar.gz

ADD ${AGAVE_DOWNLOAD_URL} ./agave.tar.gz
RUN tar --strip-components=1 -zxvf agave.tar.gz -C /agave
RUN ./scripts/cargo-install-all.sh .

FROM debian:bookworm-slim

RUN apt-get update -y && apt-get install -y \
    ca-certificates \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /agave/bin/ /usr/local/bin/

ENTRYPOINT ["agave-validator"]
