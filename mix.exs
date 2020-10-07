defmodule Zero.MixProject do
  use Mix.Project

  @version "0.7.3"

  def project do
    [
      apps_path: "apps",
      version: @version,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:distillery, "~> 2.0"},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end
end
