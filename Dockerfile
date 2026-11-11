FROM elixir:1.17-otp-26-slim AS builder

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends build-essential git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

RUN mkdir config
COPY config/config.exs config/prod.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix compile
RUN mix phx.digest

COPY config/runtime.exs config/
RUN mix release

FROM debian:bookworm-slim AS runner

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV MIX_ENV="prod"
ENV PORT="10000"
ENV RELEASE_DISTRIBUTION="none"

WORKDIR /app

RUN groupadd --system app && \
    useradd --system --gid app --home /app app

COPY --from=builder --chown=app:app /app/_build/prod/rel/geo_el ./
COPY --from=builder --chown=app:app /app/priv/data ./priv/data

USER app

EXPOSE 10000

CMD ["/app/bin/geo_el", "start"]

