# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltfProcessing.Fixtures do
  @moduledoc """
  Test fixtures for aria_gltf_processing tests.

  Provides utilities for:
  - Loading test fixtures (glTF, FBX, OBJ files)
  - Creating minimal document structures for testing
  """

  @fixtures_dir Path.join([__DIR__, "..", "fixtures"])

  @doc """
  Gets the path to a fixture file.

  ## Examples

      iex> AriaGltfProcessing.Fixtures.fixture_path("simple_cube.gltf")
      "/path/to/test/fixtures/simple_cube.gltf"
  """
  @spec fixture_path(String.t()) :: String.t()
  def fixture_path(filename) do
    Path.join(@fixtures_dir, filename)
  end

  @doc """
  Loads a glTF fixture file.

  Returns `{:ok, path}` if the file exists, `{:error, :not_found}` otherwise.
  """
  @spec load_gltf_fixture(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def load_gltf_fixture(filename) do
    path = fixture_path(filename)
    if File.exists?(path) do
      {:ok, path}
    else
      {:error, :not_found}
    end
  end

  @doc """
  Loads an FBX fixture file.

  Returns `{:ok, path}` if the file exists, `{:error, :not_found}` otherwise.
  """
  @spec load_fbx_fixture(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def load_fbx_fixture(filename) do
    path = fixture_path(filename)
    if File.exists?(path) do
      {:ok, path}
    else
      {:error, :not_found}
    end
  end

  @doc """
  Loads an OBJ fixture file.

  Returns `{:ok, path}` if the file exists, `{:error, :not_found}` otherwise.
  """
  @spec load_obj_fixture(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def load_obj_fixture(filename) do
    path = fixture_path(filename)
    if File.exists?(path) do
      {:ok, path}
    else
      {:error, :not_found}
    end
  end

  @doc """
  Creates a minimal glTF document structure for testing.

  ## Options

  - `:meshes` - List of meshes (default: empty list)
  - `:materials` - List of materials (default: empty list)
  - `:scenes` - List of scenes (default: empty list)
  - `:scene` - Default scene index (default: nil)

  ## Examples

      iex> document = AriaGltfProcessing.Fixtures.create_minimal_gltf()
      iex> document.meshes
      []
  """
  @spec create_minimal_gltf(keyword()) :: map()
  def create_minimal_gltf(opts \\ []) do
    # Return a map structure compatible with Document operations
    # Full struct construction requires module compilation
    meshes = Keyword.get(opts, :meshes, [])
    materials = Keyword.get(opts, :materials, [])
    scenes = Keyword.get(opts, :scenes, [])
    scene = Keyword.get(opts, :scene, nil)

    %{
      asset: %{version: "2.0", generator: "AriaGltfProcessing.Test"},
      buffers: [%{uri: nil, byte_length: 0, data: <<>>}],
      buffer_views: [],
      accessors: [],
      meshes: meshes,
      materials: materials,
      scenes: scenes,
      scene: scene,
      nodes: [],
      images: [],
      textures: [],
      samplers: [],
      animations: [],
      skins: [],
      cameras: []
    }
  end

  @doc """
  Creates a minimal FBX document structure for testing.

  ## Options

  - `:version` - FBX version string (default: "FBX 7.0")
  - `:nodes` - List of nodes (default: empty list)
  - `:meshes` - List of meshes (default: empty list)
  - `:materials` - List of materials (default: empty list)

  ## Examples

      iex> document = AriaGltfProcessing.Fixtures.create_minimal_fbx()
      iex> document.nodes
      []
  """
  @spec create_minimal_fbx(keyword()) :: map()
  def create_minimal_fbx(opts \\ []) do
    # Return a map structure compatible with Document operations
    # Full struct construction requires module compilation
    version = Keyword.get(opts, :version, "FBX 7.0")
    nodes = Keyword.get(opts, :nodes, [])
    meshes = Keyword.get(opts, :meshes, [])
    materials = Keyword.get(opts, :materials, [])

    %{
      version: version,
      nodes: nodes,
      meshes: meshes,
      materials: materials
    }
  end

  @doc """
  Creates a simple cube mesh for glTF.

  Returns a minimal glTF mesh with a cube primitive (8 vertices, 12 triangles).
  Note: This creates a mesh structure but does not include buffer data.
  For full functionality, use load_gltf_fixture("simple_cube.gltf") instead.
  """
  @spec create_cube_mesh() :: map()
  def create_cube_mesh do
    # Return a map structure compatible with Mesh operations
    # Full struct construction requires module compilation
    # 
    # Note: This fixture creates a mesh structure without buffer data.
    # For testing that requires actual geometry, use real fixture files.
    
    # Create minimal primitive as map
    primitive = %{
      attributes: %{"POSITION" => 0},
      indices: 1,
      mode: 4
    }

    %{
      name: "Cube",
      primitives: [primitive]
    }
  end
end

