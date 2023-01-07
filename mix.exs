defmodule Zero.MixProject do
  use Mix.Project

  def project do
    [
      name: :zero,
      apps_path: "apps",
      version: "0.9.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      preferred_cli_env: [
        check: :test,
        credo: :test,
        dialyzer: :test,
        doctor: :test,
        sobelow: :test
      ]
    ]
  end

  defp dialyzer do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:observer_cli, "~> 1.6"},
      {:distillery, github: "bors-ng/distillery"},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.24", only: [:dev, :test], runtime: false},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.14", only: [:dev, :test], runtime: false}
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
