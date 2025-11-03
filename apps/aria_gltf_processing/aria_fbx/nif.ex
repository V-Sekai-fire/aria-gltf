# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaFbx.Nif do
  @moduledoc """
  Elixir NIF wrapper for ufbx FBX loading functionality.

  This module provides Elixir bindings to the ufbx C library via NIFs
  (Native Implemented Functions).
  """

  @on_load :load_nif

  def load_nif do
    nif_path = :filename.join([:code.priv_dir(:aria_gltf_processing), "ufbx_nif"])
    :erlang.load_nif(nif_path, 0)
  end

  @doc """
  Loads an FBX file using the ufbx library.

  ## Parameters

  - `file_path`: Path to the FBX file

  ## Returns

  - `{:ok, scene_data}` - On successful load
  - `{:error, reason}` - On failure

  ## Examples

      {:ok, scene} = AriaFbx.Nif.load_fbx("/path/to/model.fbx")
  """
  @spec load_fbx(String.t()) :: {:ok, map()} | {:error, String.t()}
  def load_fbx(_file_path) do
    raise "NIF load_fbx/1 not implemented"
  end
end

