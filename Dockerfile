FROM elixir:otp-24-alpine

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# Copy necessary files
COPY lib lib
COPY mix.exs mix.lock ./

# Install mix dependencies
RUN mix deps.get
RUN mix deps.compile

# Build project
RUN mix compile

# Setup a release
RUN mix release --force

EXPOSE 5010
EXPOSE 5020
EXPOSE 5030
EXPOSE 5030

CMD ["_build/dev/rel/proto/bin/proto", "start_iex"]