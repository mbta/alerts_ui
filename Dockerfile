# --- Set up Elixir build ---
FROM hexpm/elixir:1.16.0-erlang-26.2.1-debian-bullseye-20231009-slim as elixir-builder

ENV LANG=C.UTF-8 MIX_ENV=prod

RUN apt-get update --allow-releaseinfo-change
RUN apt-get install --no-install-recommends --yes \
    build-essential ca-certificates git
RUN mix local.hex --force
RUN mix local.rebar --force

WORKDIR /root
ADD . .
RUN mix deps.get --only prod

# --- Build NPM assets ---
FROM node:20.10.0-alpine3.19 as assets-builder

WORKDIR /root
ADD . .

# Copy in elixir deps required to build node modules for phoenix
COPY --from=elixir-builder /root/deps ./deps

# Build dependencies in case certain packages don't have prebuild binaries
RUN apk add --no-cache --update python3 build-base

RUN npm --prefix assets ci

# --- Build Elixir release ---
FROM elixir-builder as app-builder

ENV LANG=C.UTF-8 MIX_ENV=prod
RUN apt-get update --allow-releaseinfo-change
RUN apt-get install --no-install-recommends --yes curl

WORKDIR /root

RUN curl https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
    -o aws-cert-bundle.pem

# Add frontend assets compiled in node container, required by phx.digest
COPY --from=assets-builder /root/priv/static ./priv/static
COPY --from=assets-builder /root/assets/node_modules ./assets/node_modules

RUN mix compile
RUN mix sentry.package_source_code
RUN mix assets.deploy
RUN mix release

# --- Set up runtime container ---
FROM debian:bullseye-slim

ENV LANG=C.UTF-8 MIX_ENV=prod REPLACE_OS_VARS=true

RUN apt-get update --allow-releaseinfo-change \
    && apt-get install --no-install-recommends --yes dumb-init ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN addgroup --system alertsui && adduser --system --ingroup alertsui alertsui
USER alertsui

# Set environment
ARG GIT_SHA=none
ENV MIX_ENV=prod PHX_SERVER=true TERM=xterm LANG=C.UTF-8 REPLACE_OS_VARS=true GIT_SHA=$GIT_SHA

WORKDIR /home/alertsui
COPY --from=app-builder --chown=alertsui:alertsui  /root/_build/prod/rel/alerts_ui .
COPY --from=app-builder --chown=alertsui:alertsui /root/aws-cert-bundle.pem ./priv/aws-cert-bundle.pem

# HTTP
EXPOSE 4000

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

HEALTHCHECK CMD ["bin/alerts_ui", "rpc", "1 + 1"]
CMD ["bin/alerts_ui", "start"]

