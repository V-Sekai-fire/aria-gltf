# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaObj.Document do
  @moduledoc """
  The root object for an OBJ asset.

  This module represents the top-level OBJ document structure, containing
  geometry data (vertices, normals, texture coordinates, faces), materials,
  and groups.
  """

  @type vertex :: {float(), float(), float()} | {float(), float(), float(), float()}
  @type normal :: {float(), float(), float()}
  @type texcoord :: {float(), float()} | {float(), float(), float()}
  @type face_vertex :: {non_neg_integer(), non_neg_integer() | nil, non_neg_integer() | nil}
  @type face :: [face_vertex()]
  @type material :: String.t()
  @type group :: String.t()
  @type mtl_material :: map()

  @type t :: %__MODULE__{
          vertices: [vertex()],
          normals: [normal()],
          texcoords: [texcoord()],
          faces: [face()],
          materials: [material()],
          groups: [group()],
          mtllib: String.t() | nil,
          mtl_materials: %{String.t() => mtl_material()} | nil,
          current_material: String.t() | nil,
          current_group: String.t() | nil,
          metadata: map() | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  defstruct [
    :vertices,
    :normals,
    :texcoords,
    :faces,
    :materials,
    :groups,
    :mtllib,
    :mtl_materials,
    :current_material,
    :current_group,
    :metadata,
    :extensions,
    :extras
  ]

  @doc """
  Creates a new OBJ document with empty geometry or from parsed geometry data.

  ## Options

  - `:vertices` - List of vertex tuples (default: `[]`)
  - `:normals` - List of normal tuples (default: `[]`)
  - `:texcoords` - List of texture coordinate tuples (default: `[]`)
  - `:faces` - List of face lists (default: `[]`)
  - `:materials` - List of material names (default: `[]`)
  - `:groups` - List of group names (default: `[]`)
  - `:mtllib` - MTL library filename (default: `nil`)
  - `:mtl_materials` - Map of material name to properties (default: `nil`)

  ## Examples

      iex> doc = AriaObj.Document.new()
      iex> length(doc.vertices)
      0

      iex> doc = AriaObj.Document.new(vertices: [{0.0, 0.0, 0.0}, {1.0, 0.0, 0.0}])
      iex> length(doc.vertices)
      2
  """
  @spec new() :: t()
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      vertices: Keyword.get(opts, :vertices, []),
      normals: Keyword.get(opts, :normals, []),
      texcoords: Keyword.get(opts, :texcoords, []),
      faces: Keyword.get(opts, :faces, []),
      materials: Keyword.get(opts, :materials, []),
      groups: Keyword.get(opts, :groups, []),
      mtllib: Keyword.get(opts, :mtllib),
      mtl_materials: Keyword.get(opts, :mtl_materials),
      current_material: Keyword.get(opts, :current_material),
      current_group: Keyword.get(opts, :current_group),
      metadata: Keyword.get(opts, :metadata),
      extensions: Keyword.get(opts, :extensions),
      extras: Keyword.get(opts, :extras)
    }
  end

  @doc """
  Converts OBJDocument to a map (for debugging/testing).

  ## Examples

      iex> doc = AriaObj.Document.new()
      iex> map = AriaObj.Document.to_map(doc)
      iex> map["vertices"]
      []
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = document) do
    %{
      "vertices" => document.vertices,
      "normals" => document.normals,
      "texcoords" => document.texcoords,
      "faces" => document.faces,
      "materials" => document.materials,
      "groups" => document.groups,
      "mtllib" => document.mtllib,
      "mtl_materials" => document.mtl_materials,
      "current_material" => document.current_material,
      "current_group" => document.current_group,
      "metadata" => document.metadata,
      "extensions" => document.extensions,
      "extras" => document.extras
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

  @doc """
  Converts OBJ 1-based indices to 0-based indices.

  OBJ format uses 1-based indexing, but many internal formats use 0-based.
  This function converts face indices from 1-based to 0-based.

  ## Examples

      iex> doc = AriaObj.Document.new(faces: [[{1, nil, nil}, {2, nil, nil}, {3, nil, nil}]])
      iex> converted = AriaObj.Document.convert_to_zero_based(doc)
      iex> converted.faces
      [[{0, nil, nil}, {1, nil, nil}, {2, nil, nil}]]
  """
  @spec convert_to_zero_based(t()) :: t()
  def convert_to_zero_based(%__MODULE__{} = document) do
    %__MODULE__{
      document
      | faces:
          Enum.map(document.faces, fn face ->
            Enum.map(face, fn {v, vt, vn} ->
              v0 = if v, do: v - 1, else: nil
              vt0 = if vt, do: vt - 1, else: nil
              vn0 = if vn, do: vn - 1, else: nil
              {v0, vt0, vn0}
            end)
          end)
    }
  end

  @doc """
  Converts OBJ 0-based indices to 1-based indices (for export).

  Converts face indices from 0-based internal format to 1-based OBJ format.

  ## Examples

      iex> doc = AriaObj.Document.new(faces: [[{0, nil, nil}, {1, nil, nil}, {2, nil, nil}]])
      iex> converted = AriaObj.Document.convert_to_one_based(doc)
      iex> converted.faces
      [[{1, nil, nil}, {2, nil, nil}, {3, nil, nil}]]
  """
  @spec convert_to_one_based(t()) :: t()
  def convert_to_one_based(%__MODULE__{} = document) do
    %__MODULE__{
      document
      | faces:
          Enum.map(document.faces, fn face ->
            Enum.map(face, fn {v, vt, vn} ->
              v1 = if v, do: v + 1, else: nil
              vt1 = if vt, do: vt + 1, else: nil
              vn1 = if vn, do: vn + 1, else: nil
              {v1, vt1, vn1}
            end)
          end)
    }
  end

  @doc """
  Gets statistics about the document.

  Returns a map with counts of vertices, normals, texture coordinates, faces,
  materials, and groups.

  ## Examples

      iex> doc = AriaObj.Document.new(vertices: [{0.0, 0.0, 0.0}], faces: [[{1, nil, nil}]])
      iex> stats = AriaObj.Document.stats(doc)
      iex> stats.vertex_count
      1
      iex> stats.face_count
      1
  """
  @spec stats(t()) :: map()
  def stats(%__MODULE__{} = document) do
    %{
      vertex_count: length(document.vertices),
      normal_count: length(document.normals),
      texcoord_count: length(document.texcoords),
      face_count: length(document.faces),
      material_count: length(document.materials),
      group_count: length(document.groups),
      has_mtl: document.mtllib != nil,
      mtl_material_count: (if document.mtl_materials, do: map_size(document.mtl_materials), else: 0)
    }
  end
end

