FROM solanalabs/solana:v1.17.31

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -y \
    && apt-get install -y curl jq \
    && rm -rf /var/lib/apt/lists/*