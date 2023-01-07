defmodule ZeroWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :zero_web,
      version: "0.9.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ZeroWeb.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:zero_game, in_umbrella: true},
      {:gen_stage, "~> 1.0"},
      {:elixir_uuid, "~> 1.1"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.3"},
      {:etag_plug, "~> 1.0"},
      {:eqrcode, "~> 0.1"},
      {:doctor, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end
end
