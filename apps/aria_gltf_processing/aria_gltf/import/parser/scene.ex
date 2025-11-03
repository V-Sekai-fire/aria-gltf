# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Import.Parser.Scene do
  @moduledoc """
  Scene-related parsing for glTF content.

  This module handles parsing of assets, scenes, nodes, and cameras from glTF JSON data.
  """

  alias AriaGltf.{Asset, Scene, Node, Camera}
  alias AriaGltf.Import.Parser.Utility

  @doc """
  Parses asset information from glTF JSON data.

  ## Examples

      iex> asset_data = %{"version" => "2.0", "generator" => "Blender"}
      iex> AriaGltf.Import.Parser.Scene.parse_asset(asset_data)
      %AriaGltf.Asset{version: "2.0", generator: "Blender"}
  """
  @spec parse_asset(map() | nil) :: Asset.t() | nil
  def parse_asset(nil), do: nil

  def parse_asset(asset_data) when is_map(asset_data) do
    %Asset{
      copyright: asset_data["copyright"],
      generator: asset_data["generator"],
      version: asset_data["version"],
      min_version: asset_data["minVersion"],
      extensions: asset_data["extensions"],
      extras: asset_data["extras"]
    }
  end

  @doc """
  Parses scenes array from glTF JSON data.

  ## Examples

      iex> scenes_data = [%{"name" => "Scene", "nodes" => [0, 1]}]
      iex> AriaGltf.Import.Parser.Scene.parse_scenes(scenes_data)
      [%AriaGltf.Scene{name: "Scene", nodes: [0, 1]}]
  """
  @spec parse_scenes(list() | nil) :: [Scene.t()]
  def parse_scenes(nil), do: []

  def parse_scenes(scenes_data) when is_list(scenes_data) do
    Enum.map(scenes_data, &parse_scene/1)
  end

  @spec parse_scene(map()) :: Scene.t()
  defp parse_scene(scene_data) when is_map(scene_data) do
    %Scene{
      name: scene_data["name"],
      nodes: scene_data["nodes"] || [],
      extensions: scene_data["extensions"],
      extras: scene_data["extras"]
    }
  end

  @doc """
  Parses nodes array from glTF JSON data.

  ## Examples

      iex> nodes_data = [%{"name" => "Cube", "mesh" => 0}]
      iex> AriaGltf.Import.Parser.Scene.parse_nodes(nodes_data)
      [%AriaGltf.Node{name: "Cube", mesh: 0}]
  """
  @spec parse_nodes(list() | nil) :: [Node.t()]
  def parse_nodes(nil), do: []

  def parse_nodes(nodes_data) when is_list(nodes_data) do
    Enum.map(nodes_data, &parse_node/1)
  end

  @spec parse_node(map()) :: Node.t()
  defp parse_node(node_data) when is_map(node_data) do
    %Node{
      name: node_data["name"],
      camera: node_data["camera"],
      children: node_data["children"] || [],
      skin: node_data["skin"],
      matrix: Utility.parse_matrix(node_data["matrix"]),
      mesh: node_data["mesh"],
      rotation: Utility.parse_quaternion(node_data["rotation"]),
      scale: Utility.parse_vec3(node_data["scale"]),
      translation: Utility.parse_vec3(node_data["translation"]),
      weights: node_data["weights"],
      extensions: node_data["extensions"],
      extras: node_data["extras"]
    }
  end

  @doc """
  Parses cameras array from glTF JSON data.

  ## Examples

      iex> cameras_data = [%{"type" => "perspective", "perspective" => %{"yfov" => 0.7}}]
      iex> AriaGltf.Import.Parser.Scene.parse_cameras(cameras_data)
      [%AriaGltf.Camera{type: "perspective", perspective: %AriaGltf.Camera.Perspective{yfov: 0.7}}]
  """
  @spec parse_cameras(list() | nil) :: [Camera.t()]
  def parse_cameras(nil), do: []

  def parse_cameras(cameras_data) when is_list(cameras_data) do
    Enum.map(cameras_data, &parse_camera/1)
  end

  @spec parse_camera(map()) :: Camera.t()
  defp parse_camera(camera_data) when is_map(camera_data) do
    %Camera{
      name: camera_data["name"],
      type: camera_data["type"],
      orthographic: parse_orthographic(camera_data["orthographic"]),
      perspective: parse_perspective(camera_data["perspective"]),
      extensions: camera_data["extensions"],
      extras: camera_data["extras"]
    }
  end

  @spec parse_orthographic(map() | nil) :: AriaGltf.Camera.Orthographic.t() | nil
  defp parse_orthographic(nil), do: nil

  defp parse_orthographic(ortho_data) when is_map(ortho_data) do
    %AriaGltf.Camera.Orthographic{
      xmag: ortho_data["xmag"],
      ymag: ortho_data["ymag"],
      zfar: ortho_data["zfar"],
      znear: ortho_data["znear"],
      extensions: ortho_data["extensions"],
      extras: ortho_data["extras"]
    }
  end

  @spec parse_perspective(map() | nil) :: AriaGltf.Camera.Perspective.t() | nil
  defp parse_perspective(nil), do: nil

  defp parse_perspective(persp_data) when is_map(persp_data) do
    %AriaGltf.Camera.Perspective{
      aspect_ratio: persp_data["aspectRatio"],
      yfov: persp_data["yfov"],
      zfar: persp_data["zfar"],
      znear: persp_data["znear"],
      extensions: persp_data["extensions"],
      extras: persp_data["extras"]
    }
  end
end
