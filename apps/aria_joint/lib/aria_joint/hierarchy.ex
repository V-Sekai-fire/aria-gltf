# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.Hierarchy do
  @moduledoc """
  Hierarchy management for Joint nodes.

  Handles parent-child relationships, hierarchy traversal,
  and transform propagation throughout the node tree.
  """

  alias AriaJoint.{Registry, DirtyState}

  @doc """
  Establish proper bidirectional parent-child relationship.

  This creates both the parent->child and child->parent links needed for
  hierarchy traversal. Gets the latest parent state from registry to ensure
  all existing children are preserved.

  ## Examples

      {:ok, root} = Joint.new()
      {:ok, child} = Joint.new()
      {updated_parent, updated_child} = Hierarchy.establish_parent_child(root, child)

  ## Returns

  `{parent_with_child, child_with_parent}` tuple with updated nodes.
  """
  @spec establish_parent_child(AriaJoint.Joint.t(), AriaJoint.Joint.t()) ::
          {AriaJoint.Joint.t(), AriaJoint.Joint.t()}
  def establish_parent_child(parent_node, child_node) do
    # Get the latest parent state from registry to preserve existing children
    current_parent =
      case Registry.get_node_by_id(parent_node.id) do
        # Fallback to passed parent if not in registry
        nil -> parent_node
        registry_parent -> registry_parent
      end

    # Add new child to existing children list
    updated_parent = %{current_parent | children: [child_node.id | current_parent.children]}
    updated_child = %{child_node | parent: parent_node.id}
    {updated_parent, updated_child}
  end

  @doc """
  Remove node from current parent.
  """
  @spec remove_from_parent(AriaJoint.Joint.t()) :: AriaJoint.Joint.t() | {:error, term()}
  def remove_from_parent(node) do
    case get_parent_node(node) do
      nil ->
        node

      current_parent ->
        updated_parent = %{
          current_parent
          | children: List.delete(current_parent.children, node.id)
        }

        case Registry.update_node(updated_parent) do
          :ok ->
            updated_node = %{node | parent: nil}

            case Registry.update_node(updated_node) do
              :ok ->
                propagate_transform_changed(updated_node)
                updated_node

              {:error, reason} ->
                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Add node to new parent.
  """
  @spec add_to_parent(AriaJoint.Joint.t(), AriaJoint.Joint.t()) ::
          AriaJoint.Joint.t() | {:error, term()}
  def add_to_parent(node, parent_node) do
    updated_parent = %{parent_node | children: [node.id | parent_node.children]}

    case Registry.update_node(updated_parent) do
      :ok ->
        updated_node = %{node | parent: parent_node.id}

        case Registry.update_node(updated_node) do
          :ok ->
            propagate_transform_changed(updated_node)
            updated_node

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get the parent node of a node.
  """
  @spec get_parent_node(AriaJoint.Joint.t()) :: AriaJoint.Joint.t() | nil
  def get_parent_node(node) do
    case node.parent do
      nil -> nil
      parent_id -> Registry.get_node_by_id(parent_id)
    end
  end

  @doc """
  Collect all nodes in hierarchy starting from root nodes.

  Pure functional approach to gather complete node hierarchy without
  relying on Registry state during traversal. This enables functional
  nested set building.

  ## Parameters

  - `root_nodes` - List of root nodes to traverse from

  ## Returns

  List of all nodes in the hierarchy (roots + all descendants).

  ## Examples

      {:ok, root} = Joint.new()
      {:ok, child} = Joint.new(parent: root)
      all_nodes = Hierarchy.collect_hierarchy([root])
      # Returns [root, child]

  """
  @spec collect_hierarchy([AriaJoint.Joint.t()]) :: [AriaJoint.Joint.t()]
  def collect_hierarchy(root_nodes) when is_list(root_nodes) do
    root_nodes
    |> Enum.flat_map(&collect_subtree/1)
    |> Enum.uniq_by(& &1.id)
  end

  @doc """
  Propagate transform changes throughout hierarchy.
  """
  @spec propagate_transform_changed(AriaJoint.Joint.t()) :: :ok
  def propagate_transform_changed(node) do
    try do
      do_propagate_transform_changed(node)
    rescue
      # Continue despite propagation failure
      _error -> :ok
    end
  end

  # Private implementation functions

  @spec collect_subtree(AriaJoint.Joint.t()) :: [AriaJoint.Joint.t()]
  defp collect_subtree(node) do
    # Get current node from registry to ensure we have latest state
    current_node =
      case Registry.get_node_by_id(node.id) do
        # Fallback to passed node if not in registry
        nil -> node
        registry_node -> registry_node
      end

    # Get all children from registry with retry logic
    children = collect_children_with_retry(current_node, 3)

    # Recursively collect children and their descendants
    child_nodes = Enum.flat_map(children, &collect_subtree/1)

    # Return current node plus all descendants
    [current_node | child_nodes]
  end

  @spec collect_children_with_retry(AriaJoint.Joint.t(), non_neg_integer()) :: [
          AriaJoint.Joint.t()
        ]
  defp collect_children_with_retry(node, retries_left) do
    children =
      for child_id <- node.children do
        case Registry.get_node_by_id(child_id) do
          # Skip missing children
          nil -> nil
          child_node -> child_node
        end
      end
      |> Enum.reject(&is_nil/1)

    # If we're missing children and have retries left, try again
    missing_count = length(node.children) - length(children)

    if missing_count > 0 and retries_left > 0 do
      # Small delay to allow registry updates to complete
      Process.sleep(1)
      collect_children_with_retry(node, retries_left - 1)
    else
      children
    end
  end

  @spec do_propagate_transform_changed(AriaJoint.Joint.t()) :: :ok
  defp do_propagate_transform_changed(node) do
    # Remove any null references and propagate to valid children
    valid_children =
      for child_id <- node.children do
        case Registry.get_node_by_id(child_id) do
          nil ->
            nil

          child_node ->
            # Mark child as dirty and propagate to its children
            dirty_child = %{
              child_node
              | dirty: DirtyState.add_dirty_flag(child_node.dirty, DirtyState.dirty_global())
            }

            Registry.update_node(dirty_child)
            propagate_transform_changed(dirty_child)
            child_id
        end
      end
      |> Enum.reject(&is_nil/1)

    # Update node with cleaned children list if needed
    updated_node =
      if length(valid_children) != length(node.children) do
        %{node | children: valid_children}
      else
        node
      end

    # Mark this node as globally dirty and update in registry
    final_node = %{
      updated_node
      | dirty: DirtyState.add_dirty_flag(updated_node.dirty, DirtyState.dirty_global())
    }

    Registry.update_node(final_node)
    :ok
  end
end
