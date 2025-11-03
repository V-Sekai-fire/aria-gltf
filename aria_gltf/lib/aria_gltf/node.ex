# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Node do
  @moduledoc """
  A node in the node hierarchy.

  This module represents a node as defined in the glTF 2.0 specification.
  Nodes define the hierarchy and transformations in a glTF scene.
  """

  @type t :: %__MODULE__{
          camera: non_neg_integer() | nil,
          children: [non_neg_integer()] | nil,
          skin: non_neg_integer() | nil,
          matrix: [float()] | nil,
          mesh: non_neg_integer() | nil,
          rotation: [float()] | nil,
          scale: [float()] | nil,
          translation: [float()] | nil,
          weights: [float()] | nil,
          name: String.t() | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  defstruct [
    :camera,
    :children,
    :skin,
    :matrix,
    :mesh,
    :rotation,
    :scale,
    :translation,
    :weights,
    :name,
    :extensions,
    :extras
  ]

  @doc """
  Creates a new node.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new node with name and options.
  """
  @spec new(String.t(), map()) :: t()
  def new(name, options \\ %{}) when is_binary(name) do
    %__MODULE__{
      name: name,
      camera: Map.get(options, :camera),
      children: Map.get(options, :children),
      skin: Map.get(options, :skin),
      matrix: Map.get(options, :matrix),
      mesh: Map.get(options, :mesh),
      rotation: Map.get(options, :rotation),
      scale: Map.get(options, :scale),
      translation: Map.get(options, :translation),
      weights: Map.get(options, :weights),
      extensions: Map.get(options, :extensions),
      extras: Map.get(options, :extras)
    }
  end

  @doc """
  Parses a node from JSON data.
  """
  @spec from_json(map()) :: t()
  def from_json(json) when is_map(json) do
    %__MODULE__{
      camera: Map.get(json, "camera"),
      children: Map.get(json, "children"),
      skin: Map.get(json, "skin"),
      matrix: Map.get(json, "matrix"),
      mesh: Map.get(json, "mesh"),
      rotation: Map.get(json, "rotation"),
      scale: Map.get(json, "scale"),
      translation: Map.get(json, "translation"),
      weights: Map.get(json, "weights"),
      name: Map.get(json, "name"),
      extensions: Map.get(json, "extensions"),
      extras: Map.get(json, "extras")
    }
  end

  @doc """
  Converts the node to JSON format.
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = node) do
    %{}
    |> put_if_present("camera", node.camera)
    |> put_if_present("children", node.children)
    |> put_if_present("skin", node.skin)
    |> put_if_present("matrix", node.matrix)
    |> put_if_present("mesh", node.mesh)
    |> put_if_present("rotation", node.rotation)
    |> put_if_present("scale", node.scale)
    |> put_if_present("translation", node.translation)
    |> put_if_present("weights", node.weights)
    |> put_if_present("name", node.name)
    |> put_if_present("extensions", node.extensions)
    |> put_if_present("extras", node.extras)
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
end
