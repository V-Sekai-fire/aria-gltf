# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaFbx.Import do
  @moduledoc """
  FBX file import functionality.

  Provides functions to load FBX files using the ufbx library via NIFs
  and convert them to FBXDocument structures, aligned with the
  AriaGltf.Import API.
  """

  alias AriaFbx.{Document, Nif, Parser}

  @doc """
  Loads an FBX file from disk and returns an FBXDocument.

  ## Options

  - `:validate` - Whether to validate the FBX file (default: `true`)

  ## Examples

      {:ok, document} = AriaFbx.Import.from_file("/path/to/model.fbx")
      {:error, reason} = AriaFbx.Import.from_file("/path/to/invalid.fbx")

      # Skip validation
      {:ok, document} = AriaFbx.Import.from_file("/path/to/model.fbx", validate: false)
  """
  @spec from_file(String.t(), keyword()) :: {:ok, Document.t()} | {:error, term()}
  def from_file(file_path, opts \\ []) when is_binary(file_path) do
    validate? = Keyword.get(opts, :validate, true)

    case Nif.load_fbx(file_path) do
      {:ok, ufbx_data} ->
        document = Parser.from_ufbx_scene(ufbx_data)

        if validate? do
          # TODO: Add validation
          document
        else
          document
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Loads an FBX file from binary data.

  ## Options

  - `:validate` - Whether to validate the FBX file (default: `true`)

  ## Examples

      {:ok, document} = AriaFbx.Import.from_binary(binary_data)
  """
  @spec from_binary(binary(), keyword()) :: {:ok, Document.t()} | {:error, term()}
  def from_binary(binary_data, opts \\ []) when is_binary(binary_data) do
    # TODO: Implement binary loading via NIF
    # This would require ufbx_load_memory or similar
    {:error, :not_implemented}
  end
end

