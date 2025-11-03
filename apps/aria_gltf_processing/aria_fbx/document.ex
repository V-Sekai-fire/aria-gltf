# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaFbx.Document do
  @moduledoc """
  The root object for an FBX asset.

  This module represents the top-level FBX document structure, aligned with
  the GLTFDocument API where possible to enable unified processing.
  """

  alias AriaFbx.Scene

  @type t :: %__MODULE__{
          version: String.t(),
          nodes: [Scene.Node.t()] | nil,
          meshes: [Scene.Mesh.t()] | nil,
          materials: [Scene.Material.t()] | nil,
          textures: [Scene.Texture.t()] | nil,
          animations: [Scene.Animation.t()] | nil,
          metadata: map() | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  @enforce_keys [:version]
  defstruct [
    :version,
    :nodes,
    :meshes,
    :materials,
    :textures,
    :animations,
    :metadata,
    :extensions,
    :extras
  ]

  @doc """
  Creates a new FBX document with the required version information.
  """
  @spec new(String.t()) :: t()
  def new(version \\ "FBX 7.4") do
    %__MODULE__{version: version}
  end

  @doc """
  Converts FBXDocument to JSON (for debugging/testing).

  ## Examples

      iex> doc = AriaFbx.Document.new()
      iex> json = AriaFbx.Document.to_json(doc)
      iex> json["version"]
      "FBX 7.4"
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = document) do
    %{
      "version" => document.version,
      "nodes" => encode_optional_list(document.nodes, &Scene.Node.to_json/1),
      "meshes" => encode_optional_list(document.meshes, &Scene.Mesh.to_json/1),
      "materials" => encode_optional_list(document.materials, &Scene.Material.to_json/1),
      "textures" => encode_optional_list(document.textures, &Scene.Texture.to_json/1),
      "animations" => encode_optional_list(document.animations, &Scene.Animation.to_json/1),
      "metadata" => document.metadata,
      "extensions" => document.extensions,
      "extras" => document.extras
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

  defp encode_optional_list(nil, _encoder), do: nil
  defp encode_optional_list(list, encoder) when is_list(list) do
    Enum.map(list, encoder)
  end
end

