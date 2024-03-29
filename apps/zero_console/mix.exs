defmodule ZeroConsole.MixProject do
  use Mix.Project

  def project do
    [
      app: :zero_console,
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
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:zero_game, in_umbrella: true},
      {:doctor, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end
end
