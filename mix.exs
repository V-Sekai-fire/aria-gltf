# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltfUmbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0-dev1",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:aria_math],
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      description: "ARIA glTF - glTF 2.0 processing library with joint hierarchy management",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:nx, "~> 0.10"},
      {:torchx, "~> 0.10"},
      {:aria_math, git: "https://github.com/V-Sekai-fire/aria-math.git"},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["K. S. Ernest (iFire) Lee"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/V-Sekai-fire/aria-gltf"}
    ]
  end
end
