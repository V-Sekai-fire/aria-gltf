# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Scene do
  @moduledoc """
  The root nodes of a scene.

  This module represents a scene as defined in the glTF 2.0 specification.
  A scene contains a list of root nodes to render.
  """

  @type t :: %__MODULE__{
          nodes: [non_neg_integer()] | nil,
          name: String.t() | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  defstruct [
    :nodes,
    :name,
    :extensions,
    :extras
  ]

  @doc """
  Creates a new scene.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new scene with the given root nodes.
  """
  @spec new([non_neg_integer()]) :: t()
  def new(nodes) when is_list(nodes) do
    %__MODULE__{nodes: nodes}
  end

  @doc """
  Creates a new scene with name, node indices, and options.
  """
  @spec new(String.t(), [non_neg_integer()], map()) :: t()
  def new(name, node_indices, options \\ %{}) when is_binary(name) and is_list(node_indices) do
    %__MODULE__{
      name: name,
      nodes: node_indices,
      extensions: Map.get(options, :extensions),
      extras: Map.get(options, :extras)
    }
  end

  @doc """
  Parses a scene from JSON data.
  """
  @spec from_json(map()) :: t()
  def from_json(json) when is_map(json) do
    %__MODULE__{
      nodes: Map.get(json, "nodes"),
      name: Map.get(json, "name"),
      extensions: Map.get(json, "extensions"),
      extras: Map.get(json, "extras")
    }
  end

  @doc """
  Converts the scene to JSON format.
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = scene) do
    %{}
    |> put_if_present("nodes", scene.nodes)
    |> put_if_present("name", scene.name)
    |> put_if_present("extensions", scene.extensions)
    |> put_if_present("extras", scene.extras)
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
end
