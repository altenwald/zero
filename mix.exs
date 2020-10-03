defmodule Zero.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.7.0",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:distillery, "~> 2.0"}
    ]
  end
end
