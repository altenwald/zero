defmodule Zero.MixProject do
  use Mix.Project

  def project do
    [
      app: :zero,
      version: "0.2.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Zero.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_state_machine, "~> 2.0"},
      {:gen_stage, "~> 0.14"},
      {:uuid, "~> 1.1"},
      {:jason, "~> 1.1"},
      {:plug_cowboy, "~> 2.0"},
      {:etag_plug, "~> 0.2.0"},
      {:eqrcode, "~> 0.1.6"},

      # for releases
      {:distillery, "~> 2.0"},
    ]
  end
end
