# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaEwbik.MixProject do
  use Mix.Project

  def project do
    [
      app: :aria_ewbik,
      version: "0.1.0-dev1",
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
      mod: {AriaEwbik.Application, []}
    ]
  end

  defp deps do
    [
      # Mathematical foundation
      {:aria_math, git: "https://github.com/V-Sekai-fire/aria-math.git"},
      # Joint hierarchy management
      {:aria_joint, in_umbrella: true}
      # Note: aria_qcp dependency removed for now - can be added later if needed
    ]
  end
end
