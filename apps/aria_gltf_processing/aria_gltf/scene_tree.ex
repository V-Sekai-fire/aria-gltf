# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.SceneTree do
  @moduledoc """
  Scene tree building utilities for aria-gltf.
  
  Provides functions for building aria-gltf scene tree structures from various
  input formats (joint hierarchies, bone lists, etc.).
  
  This module works with simple map-based data structures and builds glTF-style
  scene trees. For more advanced transform hierarchy management with dirty state
  tracking and efficient updates, see `AriaJoint.HierarchyManager` and related
  modules in the `aria_joint` app.
  
  ## Integration with aria-joint
  
  To use this module with `AriaJoint.Joint` structures:
  1. Extract transform data from Joint nodes using `AriaJoint.Transform.get_local/1`
  2. Convert Joint structures to simple maps with `:name`, `:parent`, `:position`, `:rotation`, `:scale`
  3. Use `build_from_bones/2` with the converted data
  
  For building hierarchies from Joint nodes directly, consider using
  `AriaJoint.HierarchyManager.Builder.rebuild_from_nodes/1` which provides
  nested set optimization and efficient hierarchy management.
  """

  @doc """
  Build scene tree from joint hierarchy.
  
  Creates an aria-gltf scene tree structure with nodes and children arrays.
  
  ## Parameters
  
  - `joints`: Joint hierarchy map with `:bones` and `:hierarchy` keys
  - `transforms`: Map of transformations to apply (optional)
  
  ## Returns
  
  Scene tree structure:
  ```elixir
  %{
    scene: %{
      nodes: [
        %{
          name: "NodeName",
          translation: [x, y, z],
          rotation: [[3x3 matrix]],
          scale: [x, y, z],
          children: [child_index1, child_index2, ...]
        },
        ...
      ]
    },
    transformations: %{
      "NodeName" => %{translation: [...], rotation: [...], scale: [...]}
    }
  }
  ```
  """
  @spec build_from_joints(map(), map()) :: map()
  def build_from_joints(joints, transforms \\ %{}) do
    bones = Map.get(joints, :bones, %{})
    hierarchy = Map.get(joints, :hierarchy, %{})

    {nodes, node_index_map} = build_nodes_from_hierarchy(hierarchy, bones, transforms)

    transformations_map = build_transformations_map(nodes, node_index_map)

    %{
      scene: %{
        nodes: nodes
      },
      transformations: transformations_map
    }
  end

  @doc """
  Build scene tree from bone list.
  
  Creates an aria-gltf scene tree from a flat list of bones with parent relationships.
  
  ## Parameters
  
  - `bones`: List of bone maps with `:name`, `:parent`, `:position`, `:rotation`, `:scale`
  - `transforms`: Map of transformations to apply (optional)
  
  ## Returns
  
  Scene tree structure (same format as `build_from_joints/2`)
  """
  @spec build_from_bones(list(map()), map()) :: map()
  def build_from_bones(bones, transforms \\ %{}) when is_list(bones) do
    # Build hierarchy from flat bone list
    bone_map = Enum.into(bones, %{}, fn bone -> {Map.get(bone, :name), bone} end)

    roots =
      Enum.filter(bones, fn bone ->
        parent = Map.get(bone, :parent)
        parent == nil or parent == ""
      end)

    hierarchy = build_hierarchy_tree(roots, bone_map)
    joints = %{bones: bone_map, hierarchy: hierarchy}

    build_from_joints(joints, transforms)
  end

  # Private functions

  defp build_nodes_from_hierarchy(hierarchy, bones, transforms) do
    # Recursively build nodes from hierarchy tree
    {nodes, _} = build_nodes_recursive(hierarchy, bones, transforms, [], %{}, 0)
    {Enum.reverse(nodes), %{}}  # Reverse to get correct order
  end

  defp build_nodes_recursive([], _bones, _transforms, acc_nodes, acc_map, next_index) do
    {acc_nodes, acc_map, next_index}
  end

  defp build_nodes_recursive([node_tree | rest], bones, transforms, acc_nodes, acc_map, next_index) do
    node_data = Map.get(node_tree, :node, %{})
    children = Map.get(node_tree, :children, [])

    name = Map.get(node_data, :name, "Node#{next_index}")

    # Get transform for this node
    node_transform = Map.get(transforms, name, %{
      position: Map.get(node_data, :position, [0.0, 0.0, 0.0]),
      rotation: Map.get(node_data, :rotation, [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]),
      scale: Map.get(node_data, :scale, [1.0, 1.0, 1.0])
    })

    # Build node
    node = %{
      name: name,
      translation: Map.get(node_transform, :position, Map.get(node_transform, :translation, [0.0, 0.0, 0.0])),
      rotation: Map.get(node_transform, :rotation, [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]),
      scale: Map.get(node_transform, :scale, [1.0, 1.0, 1.0]),
      children: []
    }

    # Add node
    acc_nodes = [node | acc_nodes]
    acc_map = Map.put(acc_map, name, next_index)
    current_index = next_index
    next_index = next_index + 1

    # Process children
    {acc_nodes, acc_map, next_index} =
      build_nodes_recursive(children, bones, transforms, acc_nodes, acc_map, next_index)

    # Update children array with child indices
    child_start_index = current_index + 1
    child_count = next_index - child_start_index
    children_indices = Enum.to_list(child_start_index..(next_index - 1))

    # Update node with children
    updated_node = Map.put(node, :children, children_indices)
    acc_nodes = List.replace_at(acc_nodes, 0, updated_node)

    # Continue with rest
    build_nodes_recursive(rest, bones, transforms, acc_nodes, acc_map, next_index)
  end

  defp build_hierarchy_tree(roots, bone_map) do
    Enum.map(roots, fn root ->
      children =
        bone_map
        |> Map.values()
        |> Enum.filter(fn bone -> Map.get(bone, :parent) == Map.get(root, :name) end)

      %{
        node: root,
        children: build_hierarchy_tree(children, bone_map)
      }
    end)
  end

  defp build_transformations_map(nodes, _node_index_map) do
    # Build transformations map by node name for easy lookup
    Enum.reduce(nodes, %{}, fn node, acc ->
      name = Map.get(node, :name, "unknown")
      transform = %{
        translation: Map.get(node, :translation, [0.0, 0.0, 0.0]),
        rotation: Map.get(node, :rotation, [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]),
        scale: Map.get(node, :scale, [1.0, 1.0, 1.0])
      }
      Map.put(acc, name, transform)
    end)
  end
end

