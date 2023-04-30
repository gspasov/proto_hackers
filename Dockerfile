FROM elixir:otp-24-alpine

WORKDIR /app

ARG MIX_ENV

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# Copy necessary files
COPY lib lib
COPY mix.exs mix.lock ./

# Install mix dependencies
RUN MIX_ENV=${MIX_ENV} mix deps.get
RUN MIX_ENV=${MIX_ENV} mix deps.compile

# Build project
RUN MIX_ENV=${MIX_ENV} mix compile

# Setup a release
RUN MIX_ENV=${MIX_ENV} mix release --force

ENV RELEASE_DIR=_build/$MIX_ENV/rel/proto/bin/proto

CMD $RELEASE_DIR start_iex