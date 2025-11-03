# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Import.Parser do
  @moduledoc """
  Main parser module for glTF content.

  This module coordinates the parsing of glTF JSON data into structured Elixir data types
  using specialized parser modules for different aspects of the glTF format.
  """

  alias AriaGltf.Document
  alias AriaGltf.Import.Parser.{Scene, Geometry, Material, Animation}

  @doc """
  Parses a complete glTF JSON document into a structured Document.

  ## Examples

      iex> gltf_json = %{
      ...>   "asset" => %{"version" => "2.0"},
      ...>   "scenes" => [%{"name" => "Scene", "nodes" => [0]}],
      ...>   "nodes" => [%{"name" => "Node"}]
      ...> }
      iex> AriaGltf.Import.Parser.parse_document(gltf_json)
      %AriaGltf.Document{
        asset: %AriaGltf.Asset{version: "2.0"},
        scenes: [%AriaGltf.Scene{name: "Scene", nodes: [0]}],
        nodes: [%AriaGltf.Node{name: "Node"}]
      }
  """
  @spec parse_document(map()) :: Document.t()
  def parse_document(gltf_json) when is_map(gltf_json) do
    %Document{
      # Scene-related data
      asset: Scene.parse_asset(gltf_json["asset"]),
      scene: gltf_json["scene"],
      scenes: Scene.parse_scenes(gltf_json["scenes"]),
      nodes: Scene.parse_nodes(gltf_json["nodes"]),
      cameras: Scene.parse_cameras(gltf_json["cameras"]),

      # Geometry-related data
      meshes: Geometry.parse_meshes(gltf_json["meshes"]),
      accessors: Geometry.parse_accessors(gltf_json["accessors"]),
      buffer_views: Geometry.parse_buffer_views(gltf_json["bufferViews"]),
      buffers: Geometry.parse_buffers(gltf_json["buffers"]),

      # Material-related data
      materials: Material.parse_materials(gltf_json["materials"]),
      textures: Material.parse_textures(gltf_json["textures"]),
      images: Material.parse_images(gltf_json["images"]),
      samplers: Material.parse_samplers(gltf_json["samplers"]),

      # Animation-related data
      skins: Animation.parse_skins(gltf_json["skins"]),
      animations: Animation.parse_animations(gltf_json["animations"]),

      # Extensions and extras
      extensions_used: gltf_json["extensionsUsed"] || [],
      extensions_required: gltf_json["extensionsRequired"] || [],
      extensions: gltf_json["extensions"],
      extras: gltf_json["extras"]
    }
  end

  @doc """
  Validates that required glTF fields are present.

  ## Examples

      iex> gltf_json = %{"asset" => %{"version" => "2.0"}}
      iex> AriaGltf.Import.Parser.validate_required_fields(gltf_json)
      :ok

      iex> invalid_json = %{}
      iex> AriaGltf.Import.Parser.validate_required_fields(invalid_json)
      {:error, "Missing required field: asset"}
  """
  @spec validate_required_fields(map()) :: :ok | {:error, String.t()}
  def validate_required_fields(gltf_json) when is_map(gltf_json) do
    case gltf_json do
      %{"asset" => %{"version" => _version}} ->
        :ok

      %{"asset" => _} ->
        {:error, "Missing required field: asset.version"}

      _ ->
        {:error, "Missing required field: asset"}
    end
  end

  @doc """
  Checks if the glTF version is supported.

  ## Examples

      iex> AriaGltf.Import.Parser.validate_version("2.0")
      :ok

      iex> AriaGltf.Import.Parser.validate_version("1.0")
      {:error, "Unsupported glTF version: 1.0. Only version 2.0 is supported."}
  """
  @spec validate_version(String.t()) :: :ok | {:error, String.t()}
  def validate_version("2.0"), do: :ok

  def validate_version(version) do
    {:error, "Unsupported glTF version: #{version}. Only version 2.0 is supported."}
  end

  @doc """
  Parses and validates a complete glTF JSON document.

  This function combines parsing and validation into a single operation.

  ## Examples

      iex> gltf_json = %{
      ...>   "asset" => %{"version" => "2.0"},
      ...>   "scenes" => [%{"name" => "Scene"}]
      ...> }
      iex> AriaGltf.Import.Parser.parse_and_validate(gltf_json)
      {:ok, %AriaGltf.Document{asset: %AriaGltf.Asset{version: "2.0"}}}

      iex> invalid_json = %{}
      iex> AriaGltf.Import.Parser.parse_and_validate(invalid_json)
      {:error, "Missing required field: asset"}
  """
  @spec parse_and_validate(map()) :: {:ok, Document.t()} | {:error, String.t()}
  def parse_and_validate(gltf_json) when is_map(gltf_json) do
    with :ok <- validate_required_fields(gltf_json),
         version <- get_in(gltf_json, ["asset", "version"]),
         :ok <- validate_version(version) do
      document = parse_document(gltf_json)
      {:ok, document}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
