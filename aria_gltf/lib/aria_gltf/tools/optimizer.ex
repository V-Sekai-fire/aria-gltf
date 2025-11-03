# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Tools.Optimizer do
  @moduledoc """
  Mesh optimization tools for glTF files.
  
  Uses external tools like gltfpack for mesh optimization.
  """

  require Logger

  @doc """
  Optimizes a GLB file using gltfpack.
  
  ## Options
  
  - `:compress_coordinates` - Compress vertex coordinates (default: false)
  - `:simplify_attributes` - Simplify vertex attributes (default: false)
  - `:gltfpack_path` - Path to gltfpack binary (default: searches in PATH)
  """
  @spec optimize_mesh(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def optimize_mesh(input_path, output_path, opts \\ []) do
    gltfpack_path = Keyword.get(opts, :gltfpack_path, find_gltfpack_path())
    gltfpack_args = build_gltfpack_args(opts)
    
    args = ["-i", input_path, "-o", output_path] ++ gltfpack_args

    case System.cmd(gltfpack_path, args, stderr_to_stdout: true) do
      {_output, 0} ->
        {:ok, output_path}
      {output, exit_code} ->
        {:error, "gltfpack failed with exit code #{exit_code}: #{output}"}
    end
  end

  defp find_gltfpack_path do
    # First try configured path
    case Application.get_env(:aria_gltf, :gltfpack_path) do
      nil ->
        # Try common locations
        candidate_paths = [
          "gltfpack",
          "/usr/local/bin/gltfpack",
          Path.join([:code.priv_dir(:aria_gltf), "../../thirdparty/meshoptimizer/gltfpack"] |> Enum.filter(& &1))
        ]
        
        Enum.find(candidate_paths, fn path ->
          System.find_executable(path) != nil
        end) || "gltfpack"  # Fallback to PATH
        
      configured_path ->
        configured_path
    end
  end

  defp build_gltfpack_args(opts) do
    []
    |> maybe_add_flag(:compress_coordinates, opts, "-cc")
    |> maybe_add_flag(:simplify_attributes, opts, "-sa")
    |> maybe_add_flag(:quantize_positions, opts, "-v")
    |> maybe_add_flag(:quantize_normals, opts, "-vn")
    |> maybe_add_flag(:quantize_texcoords, opts, "-vt")
    |> maybe_add_flag(:quantize_colors, opts, "-vc")
    |> Enum.reverse()
  end

  defp maybe_add_flag(acc, key, opts, flag) do
    if Keyword.get(opts, key, false) do
      [flag | acc]
    else
      acc
    end
  end
end

