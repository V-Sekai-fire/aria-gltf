# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.HierarchyManager.Builder do
  @moduledoc """
  Building and rebuilding logic for HierarchyManager.

  Handles nested set construction, hierarchy rebuilding,
  and registry synchronization.
  """

  alias AriaJoint.{Joint, NestedSet, Registry}

  @doc """
  Rebuild nested set structure from registry state.

  Gets all root joints from registry and rebuilds the entire
  nested set structure, updating joints with metadata.

  ## Parameters

  - `root_node_ids` - List of root node IDs to rebuild from

  ## Returns

  New nested set structure.
  """
  @spec rebuild_from_registry([Joint.node_id()]) :: NestedSet.nested_set()
  def rebuild_from_registry(root_node_ids) do
    # Get all root joints from registry
    root_joints =
      root_node_ids
      |> Enum.map(&get_joint_by_id/1)
      |> Enum.reject(&is_nil/1)

    # Build new nested set structure
    new_nested_set = NestedSet.build_nested_set(root_joints)

    # Update joints with nested set metadata
    update_joints_with_nested_set_metadata(new_nested_set)

    new_nested_set
  end

  @doc """
  Rebuild nested set structure from provided nodes (functional approach).

  Uses the provided node collection to build nested set without
  requiring Registry lookups.

  ## Parameters

  - `all_nodes` - Complete list of all nodes in the hierarchy

  ## Returns

  New nested set structure.
  """
  @spec rebuild_from_nodes([Joint.t()]) :: NestedSet.nested_set()
  def rebuild_from_nodes(all_nodes) do
    NestedSet.build_nested_set(all_nodes)
  end

  @doc """
  Update joints in registry with nested set metadata.

  Sets the nested_set_offset and nested_set_span fields for each
  joint in the registry based on the nested set structure.

  ## Parameters

  - `nested_set` - Nested set structure with metadata

  ## Returns

  `:ok` after updating all joints.
  """
  @spec update_joints_with_nested_set_metadata(NestedSet.nested_set()) :: :ok
  def update_joints_with_nested_set_metadata(nested_set) do
    # Update each joint in registry with its nested set offset and span
    for {node_id, %{offset: offset, span: span}} <- nested_set.node_id_to_metadata do
      case get_joint_by_id(node_id) do
        nil ->
          :ok

        joint ->
          updated_joint = %{joint | nested_set_offset: offset, nested_set_span: span}
          safe_update_joint_in_registry(updated_joint)
      end
    end

    :ok
  end

  @doc """
  Add joint and rebuild nested set if needed.

  Adds a joint to the hierarchy and rebuilds the nested set
  structure to maintain consistency.

  ## Parameters

  - `hierarchy_manager` - Current hierarchy manager
  - `joint` - Joint to add

  ## Returns

  Updated hierarchy manager with joint added and nested set rebuilt.
  """
  @spec add_joint_and_rebuild(AriaJoint.HierarchyManager.t(), Joint.t()) ::
          AriaJoint.HierarchyManager.t()
  def add_joint_and_rebuild(manager, joint) do
    # Check if this is a root node (no parent)
    updated_manager =
      if joint.parent == nil do
        %{manager | root_nodes: [joint.id | manager.root_nodes]}
      else
        manager
      end

    # Rebuild nested set structure
    new_nested_set = rebuild_from_registry(updated_manager.root_nodes)

    %{
      updated_manager
      | nested_set: new_nested_set,
        hierarchy_version: updated_manager.hierarchy_version + 1
    }
  end

  @doc """
  Remove joint and rebuild nested set.

  Removes a joint from the hierarchy and rebuilds the nested set
  structure to maintain consistency.

  ## Parameters

  - `hierarchy_manager` - Current hierarchy manager
  - `joint_id` - ID of joint to remove

  ## Returns

  Updated hierarchy manager with joint removed and nested set rebuilt.
  """
  @spec remove_joint_and_rebuild(AriaJoint.HierarchyManager.t(), Joint.node_id()) ::
          AriaJoint.HierarchyManager.t()
  def remove_joint_and_rebuild(manager, joint_id) do
    updated_manager = %{
      manager
      | root_nodes: List.delete(manager.root_nodes, joint_id),
        global_transforms: Map.delete(manager.global_transforms, joint_id)
    }

    # Rebuild nested set structure
    new_nested_set = rebuild_from_registry(updated_manager.root_nodes)

    %{
      updated_manager
      | nested_set: new_nested_set,
        hierarchy_version: updated_manager.hierarchy_version + 1
    }
  end

  # Private helper functions

  @spec get_joint_by_id(Joint.node_id()) :: Joint.t() | nil
  defp get_joint_by_id(joint_id) do
    case Registry.lookup(:joint_registry, joint_id) do
      [{_pid, joint}] -> joint
      [] -> nil
    end
  end

  @spec safe_update_joint_in_registry(Joint.t()) :: :ok
  defp safe_update_joint_in_registry(joint) do
    try do
      case Registry.lookup(:joint_registry, joint.id) do
        [{_pid, _old_joint}] ->
          Registry.update_value(:joint_registry, joint.id, fn _old -> joint end)
          :ok

        [] ->
          :ok
      end
    rescue
      _error -> :ok
    end
  end
end
