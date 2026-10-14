defmodule Zero.MixProject do
  use Mix.Project

  def project do
    [
      name: :zero,
      apps_path: "apps",
      version: "1.0.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: releases(),
      dialyzer: dialyzer()
    ]
  end

  def cli do
    [
      preferred_envs: [
        check: :test,
        credo: :test,
        dialyzer: :test,
        doctor: :test
      ]
    ]
  end

  defp dialyzer do
    [plt_add_apps: [:mix, :ex_unit]]
  end

  defp releases do
    [
      zero: [
        applications: [
          zero_game: :permanent,
          zero_web: :permanent,
          zero_console: :permanent,
          observer_cli: :permanent,
          runtime_tools: :permanent
        ],
        include_executables_for: [:unix]
      ]
    ]
  end

  # Tooling for the whole umbrella, and observer_cli to look inside the running release.
  defp deps do
    [
      {:observer_cli, "~> 1.8"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      release: ["deps.get --only prod", "compile", "release --overwrite"]
    ]
  end
end
