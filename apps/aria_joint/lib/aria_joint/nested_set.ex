# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.NestedSet do
  @moduledoc """
  Nested set model implementation for efficient bone hierarchy operations.

  Based on Godot PR #97538 optimization for Skeleton3D global bone pose calculation.
  Represents hierarchies as contiguous arrays with nested set properties for
  dramatic performance improvements in transform calculations.

  ## Nested Set Model

  Each node in the hierarchy has:
  - `nested_set_offset`: Position within the nested set array
  - `nested_set_span`: Size of subtree (node + all descendants)

  ## Example Hierarchy

      A(0,7)     <- Root at offset 0, span 7 (entire tree)
     /     \\
    B(1,4)  E(5,2)  <- B at offset 1, span 4; E at offset 5, span 2
   /    \\      \\
  C(2,1) D(3,1) F(6,1) <- Leaves at consecutive offsets

  ## Performance Benefits

  - Subtree dirty marking: O(span) vs O(depth) recursive traversal
  - Global pose calculation: Array traversal vs recursive parent lookups
  - Cache-friendly contiguous memory access patterns
  - Batch operations on dirty flags using array ranges

  ## Key Operations

  - `build_nested_set/1`: Convert parent-child relationships to nested set
  - `mark_subtree_dirty/3`: Mark entire subtree dirty in O(span) time
  - `get_dirty_range/2`: Get range of dirty nodes for batch processing
  - `update_hierarchy/2`: Rebuild nested set when hierarchy changes
  """

  alias AriaJoint.Joint

  @type nested_set_metadata :: %{
          offset: non_neg_integer(),
          span: non_neg_integer()
        }

  @type nested_set :: %{
          offset_to_node_id: %{non_neg_integer() => Joint.node_id()},
          node_id_to_metadata: %{Joint.node_id() => nested_set_metadata()},
          dirty_flags: %{non_neg_integer() => boolean()},
          size: non_neg_integer()
        }

  @doc """
  Build nested set representation from root nodes.

  Automatically discovers and includes all nodes in the hierarchy by traversing
  from the provided root nodes. Converts the complete hierarchy into a nested
  set model with contiguous array properties.

  ## Parameters

  - `root_nodes` - List of root Joint nodes to traverse from

  ## Returns

  Nested set structure with offset mappings and metadata.

  ## Example

      {:ok, root} = Joint.new()
      {:ok, child} = Joint.new(parent: root)
      nested_set = NestedSet.build_nested_set([root])
      # Automatically includes root and child in nested set

  """
  @spec build_nested_set([Joint.t()]) :: nested_set()
  def build_nested_set(root_nodes) when is_list(root_nodes) do
    if Enum.empty?(root_nodes) do
      %{
        offset_to_node_id: %{},
        node_id_to_metadata: %{},
        dirty_flags: %{},
        size: 0
      }
    else
      # Get fresh root nodes from registry to ensure we have latest children lists
      fresh_root_nodes =
        Enum.map(root_nodes, fn node ->
          case get_joint_from_registry(node.id) do
            # Fallback to original if not in registry
            nil -> node
            fresh_node -> fresh_node
          end
        end)

      # Collect complete hierarchy from fresh root nodes
      all_nodes = Joint.collect_hierarchy(fresh_root_nodes)

      # Build lookup map from all nodes in hierarchy
      node_lookup = Map.new(all_nodes, fn node -> {node.id, node} end)

      # Find actual root nodes (nodes with no parent or parent not in hierarchy)
      actual_root_nodes =
        Enum.filter(all_nodes, fn node ->
          node.parent == nil or not Map.has_key?(node_lookup, node.parent)
        end)

      initial_nested_set = %{
        offset_to_node_id: %{},
        node_id_to_metadata: %{},
        dirty_flags: %{},
        size: 0
      }

      {final_nested_set, _final_offset} =
        Enum.reduce(actual_root_nodes, {initial_nested_set, 0}, fn root_node,
                                                                   {acc_nested_set, offset} ->
          {updated_nested_set, next_offset} =
            build_nested_set_recursive(root_node, offset, acc_nested_set, node_lookup)

          {updated_nested_set, next_offset}
        end)

      final_nested_set
    end
  end

  @spec build_nested_set_recursive(Joint.t(), non_neg_integer(), nested_set(), %{
          Joint.node_id() => Joint.t()
        }) ::
          {nested_set(), non_neg_integer()}
  defp build_nested_set_recursive(node, offset, nested_set, node_lookup) do
    current_offset = offset

    # Get child nodes using lookup map
    child_nodes = get_child_nodes(node, node_lookup)

    # Process children recursively, each child gets the next available offset
    {updated_nested_set, next_offset} =
      Enum.reduce(child_nodes, {nested_set, current_offset + 1}, fn child_node,
                                                                    {acc_nested_set, child_offset} ->
        build_nested_set_recursive(child_node, child_offset, acc_nested_set, node_lookup)
      end)

    # Calculate span: from current_offset to (next_offset - 1), inclusive
    # This includes this node and all its descendants
    span = next_offset - current_offset

    # Add this node to nested set
    metadata = %{offset: current_offset, span: span}

    final_nested_set = %{
      updated_nested_set
      | offset_to_node_id: Map.put(updated_nested_set.offset_to_node_id, current_offset, node.id),
        node_id_to_metadata: Map.put(updated_nested_set.node_id_to_metadata, node.id, metadata),
        dirty_flags: Map.put(updated_nested_set.dirty_flags, current_offset, true),
        size: max(updated_nested_set.size, next_offset)
    }

    {final_nested_set, next_offset}
  end

  @doc """
  Mark entire subtree as dirty for efficient propagation.

  Uses nested set span to mark all descendants dirty in O(span) time
  instead of O(depth) recursive traversal.

  ## Parameters

  - `nested_set` - Current nested set structure
  - `node_id` - ID of node whose subtree should be marked dirty
  - `dirty_value` - Value to set for dirty flags (default: true)

  ## Returns

  Updated nested set with subtree dirty flags set.

  ## Example

      # Mark node and all descendants as needing global pose recalculation
      updated_nested_set = NestedSet.mark_subtree_dirty(nested_set, node.id)

  """
  @spec mark_subtree_dirty(nested_set(), Joint.node_id(), boolean()) :: nested_set()
  def mark_subtree_dirty(nested_set, node_id, dirty_value \\ true) do
    case Map.get(nested_set.node_id_to_metadata, node_id) do
      nil ->
        # Node not in nested set
        nested_set

      %{offset: offset, span: span} ->
        # Skip if already dirty (optimization from Godot PR)
        if not dirty_value or not Map.get(nested_set.dirty_flags, offset, false) do
          # Mark entire subtree range as dirty
          range_end = offset + span

          updated_dirty_flags =
            Enum.reduce(offset..(range_end - 1), nested_set.dirty_flags, fn i, acc ->
              Map.put(acc, i, dirty_value)
            end)

          %{nested_set | dirty_flags: updated_dirty_flags}
        else
          # Already dirty, skip
          nested_set
        end
    end
  end

  @doc """
  Get range of offsets that need processing (are dirty).

  Returns list of {offset, node_id} tuples for nodes that need updates,
  in nested set order (parents before children).

  ## Parameters

  - `nested_set` - Current nested set structure

  ## Returns

  List of {offset, node_id} tuples for dirty nodes in optimal processing order.

  ## Example

      dirty_nodes = NestedSet.get_dirty_range(nested_set)
      # Process in order to ensure parents calculated before children

  """
  @spec get_dirty_range(nested_set()) :: [{non_neg_integer(), Joint.node_id()}]
  def get_dirty_range(nested_set) do
    0..(nested_set.size - 1)
    |> Enum.filter(fn offset ->
      Map.get(nested_set.dirty_flags, offset, false)
    end)
    |> Enum.map(fn offset ->
      node_id = Map.get(nested_set.offset_to_node_id, offset)
      {offset, node_id}
    end)
    |> Enum.filter(fn {_offset, node_id} -> not is_nil(node_id) end)
  end

  @doc """
  Clear dirty flag for specific offset.

  ## Parameters

  - `nested_set` - Current nested set structure
  - `offset` - Offset to clear dirty flag for

  ## Returns

  Updated nested set with dirty flag cleared.
  """
  @spec clear_dirty_flag(nested_set(), non_neg_integer()) :: nested_set()
  def clear_dirty_flag(nested_set, offset) do
    updated_dirty_flags = Map.put(nested_set.dirty_flags, offset, false)
    %{nested_set | dirty_flags: updated_dirty_flags}
  end

  @doc """
  Check if a node is dirty in the nested set.

  ## Parameters

  - `nested_set` - Current nested set structure
  - `node_id` - Node ID to check

  ## Returns

  `true` if node is marked dirty, `false` otherwise.
  """
  @spec node_dirty?(nested_set(), Joint.node_id()) :: boolean()
  def node_dirty?(nested_set, node_id) do
    case Map.get(nested_set.node_id_to_metadata, node_id) do
      nil -> false
      %{offset: offset} -> Map.get(nested_set.dirty_flags, offset, false)
    end
  end

  @doc """
  Alias for node_dirty?/2 for backward compatibility.
  """
  @spec is_node_dirty?(nested_set(), Joint.node_id()) :: boolean()
  def is_node_dirty?(nested_set, node_id) do
    node_dirty?(nested_set, node_id)
  end

  @doc """
  Get nested set metadata for a node.

  ## Parameters

  - `nested_set` - Current nested set structure
  - `node_id` - Node ID to get metadata for

  ## Returns

  Nested set metadata with offset and span, or `nil` if not found.
  """
  @spec get_node_metadata(nested_set(), Joint.node_id()) :: nested_set_metadata() | nil
  def get_node_metadata(nested_set, node_id) do
    Map.get(nested_set.node_id_to_metadata, node_id)
  end

  @doc """
  Update hierarchy and rebuild nested set.

  Called when parent-child relationships change to maintain nested set invariants.

  ## Parameters

  - `nested_set` - Current nested set structure
  - `root_nodes` - Updated list of root nodes

  ## Returns

  Rebuilt nested set reflecting new hierarchy.
  """
  @spec update_hierarchy(nested_set(), [Joint.t()]) :: nested_set()
  def update_hierarchy(_nested_set, root_nodes) do
    # Rebuild from scratch when hierarchy changes
    build_nested_set(root_nodes)
  end

  # Private helper functions

  @spec get_child_nodes(Joint.t(), %{Joint.node_id() => Joint.t()}) :: [Joint.t()]
  defp get_child_nodes(node, node_lookup) do
    node.children
    |> Enum.map(fn child_id ->
      # First try node_lookup, then fall back to Registry
      case Map.get(node_lookup, child_id) do
        nil -> get_joint_from_registry(child_id)
        child_node -> child_node
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @spec get_joint_from_registry(Joint.node_id()) :: Joint.t() | nil
  defp get_joint_from_registry(joint_id) do
    case Registry.lookup(:joint_registry, joint_id) do
      [{_pid, joint}] -> joint
      [] -> nil
    end
  end
end
