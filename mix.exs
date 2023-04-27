defmodule ProtoHackers.MixProject do
  use Mix.Project

  def project do
    [
      app: :proto_hackers,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        proto: [
          version: "0.0.1",
          application: [proto_hackers: :permanent],
          steps: [:assemble, :tar]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ProtoHackers.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:fun_server, "~> 0.1.4"},
      {:warm_fuzzy_thing, "~> 0.1.0"},
      {:jason, "~> 1.4"},
      {:typed_struct, "~> 0.3.0"},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev], runtime: false}
    ]
  end
end
