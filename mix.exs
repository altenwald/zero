defmodule Zero.MixProject do
  use Mix.Project

  @version "0.7.8"

  def project do
    [
      apps_path: "apps",
      version: @version,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:observer_cli, "~> 1.6"},
      {:distillery, "~> 2.1"},
      {:dialyxir, "~> 1.1", only: :dev},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      release: [
        "local.hex --force",
        "local.rebar --force",
        "clean",
        "deps.get",
        "compile",
        "distillery.release --upgrade --env=prod"
      ]
    ]
  end
end
