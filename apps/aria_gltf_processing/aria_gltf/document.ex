# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Document do
  @moduledoc """
  The root object for a glTF asset.

  This module represents the top-level glTF document structure as defined in the glTF 2.0 specification.
  """

  alias AriaGltf.{
    Asset,
    Scene,
    Node,
    Mesh,
    Material,
    Texture,
    Image,
    Sampler,
    Accessor,
    BufferView,
    Buffer,
    Camera,
    Skin,
    Animation
  }

  @type t :: %__MODULE__{
          extensions_used: [String.t()] | nil,
          extensions_required: [String.t()] | nil,
          accessors: [Accessor.t()] | nil,
          animations: [Animation.t()] | nil,
          asset: Asset.t(),
          buffers: [Buffer.t()] | nil,
          buffer_views: [BufferView.t()] | nil,
          cameras: [Camera.t()] | nil,
          images: [Image.t()] | nil,
          materials: [Material.t()] | nil,
          meshes: [Mesh.t()] | nil,
          nodes: [Node.t()] | nil,
          samplers: [Sampler.t()] | nil,
          scene: non_neg_integer() | nil,
          scenes: [Scene.t()] | nil,
          skins: [Skin.t()] | nil,
          textures: [Texture.t()] | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  @enforce_keys [:asset]
  defstruct [
    :extensions_used,
    :extensions_required,
    :accessors,
    :animations,
    :asset,
    :buffers,
    :buffer_views,
    :cameras,
    :images,
    :materials,
    :meshes,
    :nodes,
    :samplers,
    :scene,
    :scenes,
    :skins,
    :textures,
    :extensions,
    :extras
  ]

  @doc """
  Creates a new glTF document with the required asset information.
  """
  @spec new(Asset.t()) :: t()
  def new(%Asset{} = asset) do
    %__MODULE__{asset: asset}
  end

  @doc """
  Parses a glTF document from JSON data.
  """
  @spec from_json(map()) :: {:ok, t()} | {:error, term()}
  def from_json(json) when is_map(json) do
    with {:ok, asset} <- parse_asset(json),
         {:ok, document} <- parse_document(json, asset) do
      {:ok, document}
    end
  end

  defp parse_asset(%{"asset" => asset_json}) do
    Asset.from_json(asset_json)
  end

  defp parse_asset(_), do: {:error, :missing_asset}

  defp parse_document(json, asset) do
    document = %__MODULE__{
      asset: asset,
      extensions_used: Map.get(json, "extensionsUsed"),
      extensions_required: Map.get(json, "extensionsRequired"),
      scene: Map.get(json, "scene"),
      extensions: Map.get(json, "extensions"),
      extras: Map.get(json, "extras")
    }

    # Parse arrays if present
    document =
      document
      |> parse_array_field(json, "accessors", &Accessor.from_json/1)
      |> parse_array_field(json, "animations", &Animation.from_json/1)
      |> parse_array_field(json, "buffers", &Buffer.from_json/1)
      |> parse_array_field(json, "bufferViews", &BufferView.from_json/1)
      |> parse_array_field(json, "cameras", &Camera.from_json/1)
      |> parse_array_field(json, "images", &Image.from_json/1)
      |> parse_array_field(json, "materials", &Material.from_json/1)
      |> parse_array_field(json, "meshes", &Mesh.from_json/1)
      |> parse_array_field(json, "nodes", &Node.from_json/1)
      |> parse_array_field(json, "samplers", &Sampler.from_json/1)
      |> parse_array_field(json, "scenes", &Scene.from_json/1)
      |> parse_array_field(json, "skins", &Skin.from_json/1)
      |> parse_array_field(json, "textures", &Texture.from_json/1)

    {:ok, document}
  end

  defp parse_array_field(document, json, field_name, parser_fn) do
    case Map.get(json, field_name) do
      nil ->
        document

      array when is_list(array) ->
        parsed_items =
          array
          |> Enum.map(parser_fn)
          |> Enum.map(fn
            {:ok, item} -> item
            {:error, _} -> nil
            item when is_struct(item) -> item
            _ -> nil
          end)
          |> Enum.reject(&is_nil/1)

        field_atom = String.to_atom(field_name)
        Map.put(document, field_atom, parsed_items)

      _ ->
        document
    end
  end

  @doc """
  Converts the document to JSON format.
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = document) do
    json = %{
      "asset" => Asset.to_json(document.asset)
    }

    json
    |> put_if_present("extensionsUsed", document.extensions_used)
    |> put_if_present("extensionsRequired", document.extensions_required)
    |> put_if_present("scene", document.scene)
    |> put_if_present("extensions", document.extensions)
    |> put_if_present("extras", document.extras)
    |> put_array_if_present("accessors", document.accessors, &Accessor.to_json/1)
    |> put_array_if_present("animations", document.animations, &Animation.to_json/1)
    |> put_array_if_present("buffers", document.buffers, &Buffer.to_json/1)
    |> put_array_if_present("bufferViews", document.buffer_views, &BufferView.to_json/1)
    |> put_array_if_present("cameras", document.cameras, &Camera.to_json/1)
    |> put_array_if_present("images", document.images, &Image.to_json/1)
    |> put_array_if_present("materials", document.materials, &Material.to_json/1)
    |> put_array_if_present("meshes", document.meshes, &Mesh.to_json/1)
    |> put_array_if_present("nodes", document.nodes, &Node.to_json/1)
    |> put_array_if_present("samplers", document.samplers, &Sampler.to_json/1)
    |> put_array_if_present("scenes", document.scenes, &Scene.to_json/1)
    |> put_array_if_present("skins", document.skins, &Skin.to_json/1)
    |> put_array_if_present("textures", document.textures, &Texture.to_json/1)
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  defp put_array_if_present(map, _key, nil, _converter), do: map
  defp put_array_if_present(map, _key, [], _converter), do: map

  defp put_array_if_present(map, key, array, converter) when is_list(array) do
    Map.put(map, key, Enum.map(array, converter))
  end
end
