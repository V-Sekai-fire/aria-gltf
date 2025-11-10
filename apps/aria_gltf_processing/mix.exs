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
      compilers: [:elixir_make | Mix.compilers()],
      make_targets: ["all"],
      make_clean: ["clean"],
      # Source files are in the app root, not in lib/
      # Include test support files in compilation
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  def application do
    # Only include mod in non-test environments
    # In test mode, modules are loaded but app doesn't need to start
    base = [
      extra_applications: [:logger]
    ]

    if Mix.env() == :test do
      # Don't specify mod in test mode to avoid startup issues
      base
    else
      Keyword.put(base, :mod, {AriaGltf.Application, []})
    end
  end

  defp elixirc_paths(:test), do: [".", "test/support"]
  defp elixirc_paths(_), do: ["."]

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:nx, "~> 0.10"},
      {:torchx, "~> 0.10"},
      {:aria_math, git: "https://github.com/V-Sekai-fire/aria-math.git"},
      {:aria_joint, in_umbrella: true},
      {:json_xema, "~> 0.6.5"},
      {:ex_mcp, git: "https://github.com/azmaveth/ex_mcp.git", ref: "46bc6fd050539b41bacd4d1409c23b1939c3728b"},
      {:abnf_parsec, "~> 2.1"},
      {:elixir_make, "~> 0.7", runtime: false}
    ]
  end
end

