FROM elixir:latest

ADD . /app

WORKDIR /app

RUN mix local.hex --force
RUN mix deps.get
RUN mix compile
RUN mix release --force --overwrite

EXPOSE 4010
EXPOSE 4020
EXPOSE 4030

CMD ["_build/dev/rel/proto/bin/proto", "start_iex"]