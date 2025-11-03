# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Helpers.DocumentCreation do
  @moduledoc """
  Helper functions for creating glTF documents, scenes, and nodes.

  This module provides utilities for creating the structural elements of
  glTF documents, including basic document setup, scene configuration,
  and node hierarchy management.
  """

  alias AriaGltf.{Document, Scene, Node, Asset}

  @doc """
  Creates a minimal glTF document with basic structure.

  ## Options

  - `:generator` - Generator information (default: "AriaGltf")
  - `:version` - glTF version (default: "2.0")
  - `:copyright` - Copyright information

  ## Examples

      iex> doc = AriaGltf.Helpers.DocumentCreation.create_minimal_document()
      iex> doc.asset.version
      "2.0"
      iex> doc.asset.generator
      "AriaGltf"
      iex> doc.scene
      0

      iex> doc = AriaGltf.Helpers.DocumentCreation.create_minimal_document(generator: "MyApp", copyright: "2025 MyCompany")
      iex> doc.asset.generator
      "MyApp"
      iex> doc.asset.copyright
      "2025 MyCompany"
  """
  @spec create_minimal_document(keyword()) :: Document.t()
  def create_minimal_document(opts \\ []) do
    generator = Keyword.get(opts, :generator, "AriaGltf")
    version = Keyword.get(opts, :version, "2.0")
    copyright = Keyword.get(opts, :copyright)

    asset = %Asset{
      version: version,
      generator: generator,
      copyright: copyright
    }

    scene = %Scene{nodes: []}

    %Document{
      asset: asset,
      scenes: [scene],
      scene: 0,
      nodes: [],
      meshes: [],
      materials: [],
      textures: [],
      images: [],
      samplers: [],
      buffers: [],
      buffer_views: [],
      accessors: []
    }
  end

  @doc """
  Creates a simple scene with a single node.

  ## Options

  - `:name` - Scene name
  - `:node_name` - Node name
  - `:translation` - Node translation [x, y, z]
  - `:rotation` - Node rotation quaternion [x, y, z, w]
  - `:scale` - Node scale [x, y, z]

  ## Examples

      iex> AriaGltf.Helpers.DocumentCreation.create_simple_scene(name: "Main Scene", node_name: "Root")
      %AriaGltf.Scene{
        name: "Main Scene",
        nodes: [0]
      }
  """
  @spec create_simple_scene(keyword()) :: Scene.t()
  def create_simple_scene(opts \\ []) do
    name = Keyword.get(opts, :name)

    %Scene{
      name: name,
      # Reference to first node
      nodes: [0]
    }
  end

  @doc """
  Creates a node with transform properties.

  ## Options

  - `:name` - Node name
  - `:translation` - Translation [x, y, z]
  - `:rotation` - Rotation quaternion [x, y, z, w]
  - `:scale` - Scale [x, y, z]
  - `:mesh` - Mesh index reference
  - `:children` - List of child node indices

  ## Examples

      iex> AriaGltf.Helpers.DocumentCreation.create_node(name: "Cube", translation: [0, 1, 0])
      %AriaGltf.Node{
        name: "Cube",
        translation: [0, 1, 0]
      }

      iex> AriaGltf.Helpers.DocumentCreation.create_node(
      ...>   name: "Transform",
      ...>   translation: [1, 2, 3],
      ...>   rotation: [0, 0, 0, 1],
      ...>   scale: [2, 2, 2],
      ...>   mesh: 0
      ...> )
      %AriaGltf.Node{
        name: "Transform",
        translation: [1, 2, 3],
        rotation: [0, 0, 0, 1],
        scale: [2, 2, 2],
        mesh: 0
      }
  """
  @spec create_node(keyword()) :: Node.t()
  def create_node(opts \\ []) do
    %Node{
      name: Keyword.get(opts, :name),
      translation: Keyword.get(opts, :translation),
      rotation: Keyword.get(opts, :rotation),
      scale: Keyword.get(opts, :scale),
      mesh: Keyword.get(opts, :mesh),
      children: Keyword.get(opts, :children)
    }
  end
end
