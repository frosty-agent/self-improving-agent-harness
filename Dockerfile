FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install --no-install-recommends --yes sbcl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Source is mounted read-only at runtime; compiled FASLs live in this named-volume path.
ENV XDG_CACHE_HOME=/cache

ENTRYPOINT ["sbcl"]
CMD ["--noinform"]
