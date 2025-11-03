# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltfProcessing.MixProject do
  use Mix.Project

  def project do
    [
      app: :aria_gltf_processing,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AriaGltf.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:nx, "~> 0.10"},
      {:torchx, "~> 0.10"},
      {:aria_math, git: "https://github.com/V-Sekai-fire/aria-math.git"},
      {:aria_joint, in_umbrella: true}
    ]
  end
end

