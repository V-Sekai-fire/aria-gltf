# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaFbx.Parser do
  @moduledoc """
  Parses ufbx scene data into FBXDocument structure.

  This module converts the raw ufbx C library output into Elixir
  structures that can be processed uniformly with glTF documents.
  """

  alias AriaFbx.{Document, Scene}

  @doc """
  Parses a ufbx scene (from NIF) into an FBXDocument.

  Extracts nodes, meshes, materials, textures, and animations from
  the ufbx scene data structure and converts them to FBXDocument format.
  """
  @spec from_ufbx_scene(map()) :: {:ok, Document.t()} | {:error, term()}
  def from_ufbx_scene(ufbx_data) when is_map(ufbx_data) do
    # Extract nodes, meshes, materials, textures, and animations from ufbx_data
    document = Document.new(ufbx_data["version"] || "FBX 7.4")

    document =
      document
      |> parse_nodes(ufbx_data)
      |> parse_meshes(ufbx_data)
      |> parse_materials(ufbx_data)
      |> parse_textures(ufbx_data)
      |> parse_animations(ufbx_data)

    {:ok, document}
  end

  def from_ufbx_scene(_), do: {:error, :invalid_ufbx_data}

  defp parse_nodes(document, data) do
    nodes = data["nodes"] || []
    parsed_nodes = Enum.map(nodes, &parse_node/1)
    %{document | nodes: parsed_nodes}
  end

  defp parse_node(node_data) when is_map(node_data) do
    %Scene.Node{
      id: node_data["id"] || 0,
      name: node_data["name"] || "",
      parent_id: node_data["parent_id"],
      children: node_data["children"] || [],
      translation: parse_vec3(node_data["translation"]),
      rotation: parse_vec4(node_data["rotation"]),
      scale: parse_vec3(node_data["scale"]),
      mesh_id: node_data["mesh_id"],
      extensions: node_data["extensions"],
      extras: node_data["extras"]
    }
  end

  defp parse_meshes(document, data) do
    meshes = data["meshes"] || []
    parsed_meshes = Enum.map(meshes, &parse_mesh/1)
    %{document | meshes: parsed_meshes}
  end

  defp parse_mesh(mesh_data) when is_map(mesh_data) do
    %Scene.Mesh{
      id: mesh_data["id"] || 0,
      name: mesh_data["name"],
      positions: mesh_data["positions"],
      normals: mesh_data["normals"],
      texcoords: mesh_data["texcoords"],
      indices: mesh_data["indices"],
      material_ids: mesh_data["material_ids"] || [],
      extensions: mesh_data["extensions"],
      extras: mesh_data["extras"]
    }
  end

  defp parse_materials(document, data) do
    materials = data["materials"] || []
    parsed_materials = Enum.map(materials, &parse_material/1)
    %{document | materials: parsed_materials}
  end

  defp parse_material(material_data) when is_map(material_data) do
    %Scene.Material{
      id: material_data["id"] || 0,
      name: material_data["name"],
      diffuse_color: parse_vec3(material_data["diffuse_color"]),
      specular_color: parse_vec3(material_data["specular_color"]),
      emissive_color: parse_vec3(material_data["emissive_color"]),
      extensions: material_data["extensions"],
      extras: material_data["extras"]
    }
  end

  defp parse_textures(document, data) do
    textures = data["textures"] || []
    parsed_textures = Enum.map(textures, &parse_texture/1)
    %{document | textures: parsed_textures}
  end

  defp parse_texture(texture_data) when is_map(texture_data) do
    %Scene.Texture{
      id: texture_data["id"] || 0,
      name: texture_data["name"],
      file_path: texture_data["file_path"],
      extensions: texture_data["extensions"],
      extras: texture_data["extras"]
    }
  end

  defp parse_animations(document, data) do
    animations = data["animations"] || []
    parsed_animations = Enum.map(animations, &parse_animation/1)
    %{document | animations: parsed_animations}
  end

  defp parse_animation(animation_data) when is_map(animation_data) do
    keyframes = (animation_data["keyframes"] || [])
                |> Enum.map(&parse_keyframe/1)

    %Scene.Animation{
      id: animation_data["id"] || 0,
      name: animation_data["name"],
      node_id: animation_data["node_id"] || 0,
      keyframes: keyframes,
      extensions: animation_data["extensions"],
      extras: animation_data["extras"]
    }
  end

  defp parse_keyframe(keyframe_data) when is_map(keyframe_data) do
    %Scene.Animation.Keyframe{
      time: keyframe_data["time"] || 0.0,
      translation: parse_vec3(keyframe_data["translation"]),
      rotation: parse_vec4(keyframe_data["rotation"]),
      scale: parse_vec3(keyframe_data["scale"])
    }
  end

  defp parse_vec3(nil), do: nil
  defp parse_vec3([x, y, z]) when is_number(x) and is_number(y) and is_number(z), do: {x, y, z}
  defp parse_vec3(_), do: nil

  defp parse_vec4(nil), do: nil
  defp parse_vec4([x, y, z, w]) when is_number(x) and is_number(y) and is_number(z) and is_number(w), do: {x, y, z, w}
  defp parse_vec4(_), do: nil
end

