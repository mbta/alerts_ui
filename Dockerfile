# --- Set up Elixir build ---
FROM hexpm/elixir:1.15.6-erlang-26.1-debian-bullseye-20230612-slim as elixir-builder

ENV LANG=C.UTF-8 MIX_ENV=prod

RUN apt-get update --allow-releaseinfo-change
RUN apt-get install --no-install-recommends --yes \
    build-essential ca-certificates git
RUN mix local.hex --force
RUN mix local.rebar --force

WORKDIR /root
ADD . .
RUN mix deps.get --only prod

# --- Build Elixir release ---
FROM elixir-builder as app-builder

ENV LANG=C.UTF-8 MIX_ENV=prod
RUN apt-get update --allow-releaseinfo-change
RUN apt-get install --no-install-recommends --yes curl

WORKDIR /root

RUN curl https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
    -o aws-cert-bundle.pem
RUN echo "2c151768edd48e9ef6719de74fdcbdebe290d1e87bc02ce9014ea6eea557d2a0  aws-cert-bundle.pem" | sha256sum -c -

RUN mix compile
RUN mix assets.deploy
RUN mix phx.digest
RUN mix release

# --- Set up runtime container ---
FROM debian:bullseye-slim

ENV LANG=C.UTF-8 MIX_ENV=prod REPLACE_OS_VARS=true

RUN apt-get update --allow-releaseinfo-change \
    && apt-get install --no-install-recommends --yes dumb-init \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN addgroup --system alertsui && adduser --system --ingroup alertsui alertsui
USER alertsui

# Set environment
ENV MIX_ENV=prod PHX_SERVER=true TERM=xterm LANG=C.UTF-8 REPLACE_OS_VARS=true

WORKDIR /home/alertsui
COPY --from=app-builder --chown=alertsui:alertsui  /root/_build/prod/rel/alerts_ui .
COPY --from=app-builder --chown=alertsui:alertsui /root/aws-cert-bundle.pem ./priv/aws-cert-bundle.pem

# HTTP
EXPOSE 4000

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

HEALTHCHECK CMD ["bin/alerts_ui", "rpc", "1 + 1"]
CMD ["bin/alerts_ui", "start"]

