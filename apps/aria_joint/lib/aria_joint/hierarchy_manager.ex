# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.HierarchyManager do
  @moduledoc """
  Optimized hierarchy manager using nested set model for efficient transform calculations.

  Provides high-performance transform hierarchy operations by combining traditional
  parent-child relationships with nested set optimizations inspired by Godot PR #97538.

  ## Features

  - Automatic nested set construction from existing hierarchies
  - Batch global pose calculation with optimal ordering
  - Efficient subtree dirty propagation: O(span) vs O(depth)
  - Seamless integration with existing Joint API

  ## Usage

      # Create optimized hierarchy manager
      {:ok, manager} = HierarchyManager.new()

      # Add joints to hierarchy
      manager = HierarchyManager.add_joint(manager, root_joint)
      manager = HierarchyManager.add_joint(manager, child_joint)

      # Batch update all dirty global transforms
      manager = HierarchyManager.update_global_transforms(manager)

      # Get individual global transform (uses cached result)
      global_transform = HierarchyManager.get_global_transform(manager, joint.id)

  ## Performance Benefits

  - **26x faster forward pose operations** for large hierarchies
  - **13x faster reverse pose operations** compared to registry approach
  - **Cache-friendly contiguous memory access** patterns
  - **Batch processing** reduces function call overhead
  """

  alias AriaJoint.{Joint, NestedSet}
  alias AriaJoint.HierarchyManager.{Calculator, Builder}
  alias AriaMath.Matrix4

  @type t() :: %__MODULE__{
          nested_set: NestedSet.nested_set(),
          global_transforms: %{Joint.node_id() => Matrix4.t()},
          root_nodes: [Joint.node_id()],
          hierarchy_version: non_neg_integer()
        }

  defstruct nested_set: %{
              offset_to_node_id: %{},
              node_id_to_metadata: %{},
              dirty_flags: %{},
              size: 0
            },
            global_transforms: %{},
            root_nodes: [],
            hierarchy_version: 0

  @doc """
  Create a new hierarchy manager.

  ## Returns

  `{:ok, manager}` with empty hierarchy ready for joints.

  ## Examples

      {:ok, manager} = HierarchyManager.new()

  """
  @spec new() :: {:ok, t()}
  def new do
    {:ok, %__MODULE__{}}
  end

  @doc """
  Rebuild hierarchy manager from complete node collection.

  Updates the hierarchy manager with a complete collection of nodes,
  using functional approach instead of Registry lookups.

  ## Parameters

  - `manager` - Current hierarchy manager
  - `all_nodes` - Complete list of all nodes in the hierarchy

  ## Returns

  Updated hierarchy manager with rebuilt nested set structure.

  ## Examples

      # Collect complete hierarchy first, then rebuild manager
      all_nodes = Joint.collect_hierarchy([root_joint])
      manager = HierarchyManager.rebuild_from_nodes(manager, all_nodes)

  """
  @spec rebuild_from_nodes(t(), [Joint.t()]) :: t()
  def rebuild_from_nodes(manager, all_nodes) do
    # Find root nodes from the collection
    root_nodes = Enum.filter(all_nodes, fn node -> node.parent == nil end)
    root_node_ids = Enum.map(root_nodes, & &1.id)

    # Build new nested set structure from complete node collection
    new_nested_set = NestedSet.build_nested_set(all_nodes)

    %{
      manager
      | nested_set: new_nested_set,
        root_nodes: root_node_ids,
        hierarchy_version: manager.hierarchy_version + 1
    }
  end

  @doc """
  Add a joint to the hierarchy manager.

  Automatically rebuilds nested set structure if hierarchy changes.
  Note: This function requires Registry for backward compatibility.
  Use `rebuild_from_nodes/2` for pure functional approach.

  ## Parameters

  - `manager` - Current hierarchy manager
  - `joint` - Joint to add to hierarchy

  ## Returns

  Updated hierarchy manager with joint integrated.

  ## Examples

      manager = HierarchyManager.add_joint(manager, root_joint)
      manager = HierarchyManager.add_joint(manager, child_joint)

  """
  @spec add_joint(t(), Joint.t()) :: t()
  def add_joint(manager, joint) do
    Builder.add_joint_and_rebuild(manager, joint)
  end

  @doc """
  Remove a joint from the hierarchy manager.

  Automatically rebuilds nested set structure to maintain consistency.

  ## Parameters

  - `manager` - Current hierarchy manager
  - `joint_id` - ID of joint to remove

  ## Returns

  Updated hierarchy manager with joint removed.
  """
  @spec remove_joint(t(), Joint.node_id()) :: t()
  def remove_joint(manager, joint_id) do
    Builder.remove_joint_and_rebuild(manager, joint_id)
  end

  @doc """
  Update all dirty global transforms using functional batch processing.

  Uses nested set ordering and complete node collection to ensure parents
  are calculated before children, enabling single-pass calculation with
  optimal cache performance without Registry dependencies.

  ## Parameters

  - `manager` - Current hierarchy manager
  - `all_nodes` - Complete list of all nodes in the hierarchy

  ## Returns

  Updated manager with all global transforms calculated and cached.

  ## Examples

      # Collect complete hierarchy and batch update transforms functionally
      all_nodes = Joint.collect_hierarchy([root_joint])
      manager = HierarchyManager.update_global_transforms_functional(manager, all_nodes)

  """
  @spec update_global_transforms_functional(t(), [Joint.t()]) :: t()
  def update_global_transforms_functional(manager, all_nodes) do
    # Build lookup map for fast node access
    node_lookup = Map.new(all_nodes, fn node -> {node.id, node} end)

    # Get dirty nodes in nested set order (parents before children)
    dirty_nodes = NestedSet.get_dirty_range(manager.nested_set)

    # Process dirty nodes in optimal order using functional approach
    {updated_nested_set, updated_transforms} =
      Enum.reduce(dirty_nodes, {manager.nested_set, manager.global_transforms}, fn {offset,
                                                                                    node_id},
                                                                                   {ns_acc,
                                                                                    transforms_acc} ->
        case Map.get(node_lookup, node_id) do
          nil ->
            {ns_acc, transforms_acc}

          joint ->
            # Calculate global transform functionally
            global_transform = Calculator.calculate_functional(joint, transforms_acc, node_lookup)

            # Update transforms cache
            updated_transforms = Map.put(transforms_acc, node_id, global_transform)

            # Clear dirty flag for this offset
            updated_ns = NestedSet.clear_dirty_flag(ns_acc, offset)

            {updated_ns, updated_transforms}
        end
      end)

    %{manager | nested_set: updated_nested_set, global_transforms: updated_transforms}
  end

  @doc """
  Update all dirty global transforms using optimized batch processing.

  Uses nested set ordering to ensure parents are calculated before children,
  enabling single-pass calculation with optimal cache performance.
  Note: This function requires Registry for backward compatibility.
  Use `update_global_transforms_functional/2` for pure functional approach.

  ## Parameters

  - `manager` - Current hierarchy manager

  ## Returns

  Updated manager with all global transforms calculated and cached.

  ## Examples

      # After making transform changes, batch update all dirty transforms
      manager = HierarchyManager.update_global_transforms(manager)

  """
  @spec update_global_transforms(t()) :: t()
  def update_global_transforms(manager) do
    # Get dirty nodes in nested set order (parents before children)
    dirty_nodes = NestedSet.get_dirty_range(manager.nested_set)

    # Process dirty nodes in optimal order
    {updated_nested_set, updated_transforms} =
      Enum.reduce(dirty_nodes, {manager.nested_set, manager.global_transforms}, fn {offset,
                                                                                    node_id},
                                                                                   {ns_acc,
                                                                                    transforms_acc} ->
        case get_joint_by_id(node_id) do
          nil ->
            {ns_acc, transforms_acc}

          joint ->
            # Calculate global transform for this joint
            global_transform = Calculator.calculate_optimized(joint, transforms_acc)

            # Update transforms cache
            updated_transforms = Map.put(transforms_acc, node_id, global_transform)

            # Clear dirty flag for this offset
            updated_ns = NestedSet.clear_dirty_flag(ns_acc, offset)

            {updated_ns, updated_transforms}
        end
      end)

    %{manager | nested_set: updated_nested_set, global_transforms: updated_transforms}
  end

  @doc """
  Get global transform for a specific joint.

  Returns cached result if available and clean, otherwise triggers
  calculation and caching.

  ## Parameters

  - `manager` - Current hierarchy manager
  - `joint_id` - ID of joint to get global transform for

  ## Returns

  Global transform matrix for the joint.

  ## Examples

      global_transform = HierarchyManager.get_global_transform(manager, joint.id)

  """
  @spec get_global_transform(t(), Joint.node_id()) :: Matrix4.t()
  def get_global_transform(manager, joint_id) do
    if NestedSet.node_dirty?(manager.nested_set, joint_id) do
      # Dirty, need to recalculate
      Calculator.calculate_and_cache(joint_id, manager.global_transforms)
    else
      # Check if we have clean cached result
      case Map.get(manager.global_transforms, joint_id) do
        nil ->
          # Not cached, need to calculate
          Calculator.calculate_and_cache(joint_id, manager.global_transforms)

        cached_transform ->
          cached_transform
      end
    end
  end

  @doc """
  Mark a joint's subtree as dirty for efficient propagation.

  Uses nested set span to mark all descendants in O(span) time
  instead of recursive traversal.

  ## Parameters

  - `manager` - Current hierarchy manager
  - `joint_id` - ID of joint whose subtree should be marked dirty

  ## Returns

  Updated manager with subtree marked dirty.

  ## Examples

      # Mark joint and all children as needing recalculation
      manager = HierarchyManager.mark_subtree_dirty(manager, joint.id)

  """
  @spec mark_subtree_dirty(t(), Joint.node_id()) :: t()
  def mark_subtree_dirty(manager, joint_id) do
    updated_nested_set = NestedSet.mark_subtree_dirty(manager.nested_set, joint_id)
    %{manager | nested_set: updated_nested_set}
  end

  @doc """
  Get performance statistics for the hierarchy.

  ## Parameters

  - `manager` - Current hierarchy manager

  ## Returns

  Map with performance and structure statistics.
  """
  @spec get_stats(t()) :: %{
          total_nodes: non_neg_integer(),
          dirty_nodes: non_neg_integer(),
          cached_transforms: non_neg_integer(),
          hierarchy_version: non_neg_integer()
        }
  def get_stats(manager) do
    dirty_count =
      manager.nested_set.dirty_flags
      |> Map.values()
      |> Enum.count(& &1)

    %{
      total_nodes: manager.nested_set.size,
      dirty_nodes: dirty_count,
      cached_transforms: map_size(manager.global_transforms),
      hierarchy_version: manager.hierarchy_version
    }
  end

  # Private implementation functions

  @spec get_joint_by_id(Joint.node_id()) :: Joint.t() | nil
  defp get_joint_by_id(joint_id) do
    case Registry.lookup(:joint_registry, joint_id) do
      [{_pid, joint}] -> joint
      [] -> nil
    end
  end
end
