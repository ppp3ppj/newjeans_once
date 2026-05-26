# Build stage
ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.5
ARG DEBIAN_VERSION=bookworm-20260518-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# Set build environment
ENV MIX_ENV="prod"

# Copy mix files and install dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Version stamp — override with: docker build --build-arg APP_VERSION=1.2.3 .
ARG APP_VERSION=0.1.0
ENV APP_VERSION=${APP_VERSION}

# Copy source and compile (generates phoenix-colocated module needed by esbuild)
COPY priv priv
COPY lib lib
RUN mix compile

# Copy assets and build them
COPY assets assets
RUN mix assets.deploy

# Copy runtime config (after compile, so it is not included in compilation)
COPY config/runtime.exs config/

# Create release
RUN mix release

# Runtime stage
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

WORKDIR /app

# Copy the release from the build stage
RUN chown nobody /app
COPY --from=builder --chown=nobody:root /app/_build/prod/rel/newjeans_once ./

# Create and own the persistent storage directory
RUN mkdir -p /storage && chown nobody:root /storage

USER nobody

ENV PHX_SERVER=true
ENV PORT=80
ENV DATABASE_PATH=/storage/newjeans_once.db

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -f http://localhost/up || exit 1

CMD ["/app/bin/newjeans_once", "start"]
