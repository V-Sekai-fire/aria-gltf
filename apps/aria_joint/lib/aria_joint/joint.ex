# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.Joint do
  @moduledoc """
  Transform hierarchy management for EWBIK bone chains.

  Joint provides efficient transform hierarchy management with parent-child
  relationships, dirty state tracking, and coordinate space conversions. This is
  a port of the IKNode3D class from the many_bone_ik project.

  ## Features

  - Local and global transform caching with dirty state optimization
  - Parent-child bone hierarchy management
  - Coordinate space conversions (local ↔ global)
  - Transform propagation throughout hierarchy
  - Scale management (can disable scale for pure rotational joints)
  - Efficient updates only when transforms are dirty

  ## Usage

      # Create root bone
      {:ok, root} = Joint.new()

      # Create child bone with parent relationship
      {:ok, child} = Joint.new(parent: root)

      # Set local transform
      child = Joint.set_transform(child, transform)

      # Get global transform (automatically computed from hierarchy)
      global_transform = Joint.get_global_transform(child)

  ## Transform Hierarchy

  Each Joint maintains:
  - **Local Transform**: Transform relative to parent bone
  - **Global Transform**: Absolute transform in world space (computed from hierarchy)
  - **Dirty State**: Tracks what needs recomputation for efficiency

  When a bone's transform changes, dirty flags propagate to children automatically.

  ## Coordinate Space Conversions

      # Convert point from world space to local bone space
      local_point = Joint.to_local(bone, world_point)

      # Convert point from local bone space to world space
      world_point = Joint.to_global(bone, local_point)

  ## Citations

  Port of IKNode3D from many_bone_ik project:
  - Original C++ implementation for Godot Engine transform hierarchy
  - Optimized dirty state tracking for real-time performance
  - Parent-child relationship management for complex bone chains
  """

  alias AriaMath.{Vector3, Matrix4}
  alias AriaJoint.{Registry, Validation, DirtyState, Hierarchy, Transform}

  @type transform() :: Matrix4.t()
  @type basis() :: Matrix4.t()
  @type node_id() :: reference()
  @type dirty_state() :: DirtyState.dirty_state()

  @type t() :: %__MODULE__{
          id: node_id(),
          global_transform: transform(),
          local_transform: transform(),
          rotation: basis(),
          scale: Vector3.t(),
          dirty: dirty_state(),
          parent: node_id() | nil,
          children: [node_id()],
          disable_scale: boolean(),
          nested_set_offset: non_neg_integer() | nil,
          nested_set_span: non_neg_integer() | nil
        }

  defstruct [
    :id,
    :global_transform,
    :local_transform,
    :rotation,
    scale: {1.0, 1.0, 1.0},
    dirty: :dirty_none,
    parent: nil,
    children: [],
    disable_scale: false,
    nested_set_offset: nil,
    nested_set_span: nil
  ]

  @type joint_error ::
          :registry_unavailable
          | :node_not_found
          | :circular_dependency
          | :hierarchy_too_deep
          | :too_many_children
          | :invalid_transform
          | :registry_timeout
          | :memory_limit_exceeded

  @doc """
  Create a new Joint with optional parent relationship.

  ## Options

  - `:parent` - Parent Joint to attach to (creates parent-child relationship)
  - `:disable_scale` - Whether to disable scale propagation (default: false)

  ## Examples

      # Create root node
      {:ok, root} = Joint.new()

      # Create child node
      {:ok, child} = Joint.new(parent: root)

      # Create node with scale disabled
      {:ok, joint} = Joint.new(disable_scale: true)

  ## Returns

  `{:ok, node}` on success, `{:error, reason}` on failure.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, joint_error() | term()}
  def new(opts \\ []) do
    # Ensure registry exists
    case Registry.ensure_registry() do
      {:error, reason} ->
        {:error, reason}

      :ok ->
        %__MODULE__{
          id: make_ref(),
          global_transform: Matrix4.identity(),
          local_transform: Matrix4.identity(),
          rotation: Matrix4.identity(),
          disable_scale: Keyword.get(opts, :disable_scale, false)
        }
        |> then(fn node ->
          case Keyword.get(opts, :parent) do
            nil ->
              # Register node and return
              case Registry.register_node(node) do
                {:ok, _pid} -> {:ok, node}
                {:error, reason} -> {:error, reason}
              end

            parent_node ->
              # Use establish_parent_child for consistent bidirectional relationships
              {updated_parent, updated_child} = Hierarchy.establish_parent_child(parent_node, node)

              # Register child first
              case Registry.register_node(updated_child) do
                {:ok, _pid} ->
                  # Update parent in registry with proper synchronization
                  case Registry.update_node(updated_parent) do
                    :ok ->
                      # Verify the update worked by checking registry
                      case Registry.get_node_by_id(parent_node.id) do
                        nil ->
                          {:error, :parent_not_found}

                        final_parent ->
                          if updated_child.id in final_parent.children do
                            {:ok, updated_child}
                          else
                            {:error, :registry_sync_failed}
                          end
                      end

                    {:error, reason} ->
                      {:error, reason}
                  end

                {:error, reason} ->
                  {:error, reason}
              end
          end
        end)
    end
  end

  @doc """
  Set the local transform of a node.

  Updates the local transform and marks appropriate dirty states for efficient
  recomputation of global transforms.

  ## Examples

      transform = Matrix4.translation({0.5, 1.0, 0.0})
      node = Joint.set_transform(node, transform)

  """
  @spec set_transform(t(), transform()) :: t() | {:error, joint_error()}
  def set_transform(node, transform) do
    with :ok <- Validation.validate_node_struct(node),
         :ok <- Validation.validate_transform_input(transform) do
      updated_node = Transform.set_local(node, transform)
      # Ensure we return the updated node from registry if available
      case Registry.get_node_by_id(updated_node.id) do
        nil -> updated_node
        registry_node -> registry_node
      end
    end
  end

  @doc """
  Set the global transform of a node.

  Automatically computes the appropriate local transform based on parent hierarchy.

  ## Examples

      global_transform = Matrix4.translation({1.0, 2.0, 3.0})
      node = Joint.set_global_transform(node, global_transform)

  """
  @spec set_global_transform(t(), transform()) :: t()
  def set_global_transform(node, global_transform) do
    Transform.set_global(node, global_transform)
  end

  @doc """
  Get the local transform of a node.

  Updates local transform from rotation and scale if dirty.

  ## Examples

      local_transform = Joint.get_transform(node)

  """
  @spec get_transform(t()) :: transform()
  def get_transform(node) do
    Transform.get_local(node)
  end

  @doc """
  Get the global transform of a node.

  Computes global transform from hierarchy if dirty, with efficient caching.

  ## Examples

      global_transform = Joint.get_global_transform(node)

  """
  @spec get_global_transform(t()) :: transform()
  def get_global_transform(node) do
    Transform.get_global(node)
  end

  @doc """
  Set parent-child relationship between nodes.

  Automatically manages bidirectional parent-child relationships and propagates
  transform changes.

  ## Examples

      child = Joint.set_parent(child, parent)

  """
  @spec set_parent(t(), t() | nil) :: t() | {:error, joint_error()}
  def set_parent(node, nil) do
    with :ok <- Validation.validate_node_struct(node) do
      Hierarchy.remove_from_parent(node)
    end
  end

  def set_parent(node, parent_node) do
    with :ok <- Validation.validate_node_struct(node),
         :ok <- Validation.validate_node_struct(parent_node),
         :ok <- Validation.validate_no_circular_dependency(node, parent_node),
         :ok <- Validation.validate_hierarchy_constraints(parent_node) do
      # Remove from current parent if exists
      node_without_parent =
        case Hierarchy.remove_from_parent(node) do
          %__MODULE__{} = updated_node -> updated_node
          # Continue despite cleanup failure
          {:error, _reason} -> node
        end

      # Add to new parent
      Hierarchy.add_to_parent(node_without_parent, parent_node)
    end
  end

  @doc """
  Get the parent node of a node.

  ## Examples

      parent = Joint.get_parent(node)

  Returns `nil` if node has no parent.
  """
  @spec get_parent(t()) :: t() | nil
  def get_parent(node) do
    # First check if the node is still in the registry
    case Registry.get_node_by_id(node.id) do
      # Node was cleaned up, no parent
      nil -> nil
      current_node -> Hierarchy.get_parent_node(current_node)
    end
  end

  @doc """
  Convert a point from global space to local node space.

  ## Examples

      global_point = {1.0, 2.0, 3.0}
      local_point = Joint.to_local(node, global_point)

  """
  @spec to_local(t(), Vector3.t()) :: Vector3.t()
  def to_local(node, global_point) do
    Transform.to_local(node, global_point)
  end

  @doc """
  Convert a point from local node space to global space.

  ## Examples

      local_point = {0.5, 0.0, 0.0}
      global_point = Joint.to_global(node, local_point)

  """
  @spec to_global(t(), Vector3.t()) :: Vector3.t()
  def to_global(node, local_point) do
    Transform.to_global(node, local_point)
  end

  @doc """
  Rotate node locally using global basis.

  ## Parameters

  - `node` - The node to rotate
  - `basis` - Global rotation basis to apply
  - `propagate` - Whether to propagate changes to children (default: false)

  ## Examples

      rotation_basis = Matrix4.rotation_y(Math.pi / 4)
      node = Joint.rotate_local_with_global(node, rotation_basis, true)

  """
  @spec rotate_local_with_global(t(), basis(), boolean()) :: t()
  def rotate_local_with_global(node, basis, propagate \\ false) do
    Transform.rotate_local_with_global(node, basis, propagate)
  end

  @doc """
  Enable or disable scale propagation for this node.

  When scale is disabled, the node will orthogonalize its global transform
  to remove scaling effects.

  ## Examples

      node = Joint.set_disable_scale(node, true)

  """
  @spec set_disable_scale(t(), boolean()) :: t()
  def set_disable_scale(node, disable_scale) do
    updated_node = %{node | disable_scale: disable_scale}
    Registry.update_node(updated_node)
    updated_node
  end

  @doc """
  Check if scale is disabled for this node.

  ## Examples

      is_disabled = Joint.scale_disabled?(node)

  """
  @spec scale_disabled?(t()) :: boolean()
  def scale_disabled?(node) do
    node.disable_scale
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
      all_nodes = Joint.collect_hierarchy([root])
      # Returns [root, child]

  """
  @spec collect_hierarchy([t()]) :: [t()]
  def collect_hierarchy(root_nodes) when is_list(root_nodes) do
    Hierarchy.collect_hierarchy(root_nodes)
  end

  @doc """
  Clean up node and remove from hierarchy.

  Removes all parent-child relationships and cleans up registry entries.

  ## Examples

      Joint.cleanup(node)

  """
  @spec cleanup(t()) :: :ok
  def cleanup(node) do
    # Remove from parent
    case set_parent(node, nil) do
      %__MODULE__{} = updated_node ->
        # Remove all children
        for child_id <- updated_node.children do
          case Registry.get_node_by_id(child_id) do
            nil -> :ok
            child_node -> set_parent(child_node, nil)
          end
        end

        # Unregister from registry
        Registry.unregister_node(updated_node.id)
        :ok

      {:error, _reason} ->
        # Still try to clean up children and unregister
        for child_id <- node.children do
          case Registry.get_node_by_id(child_id) do
            nil -> :ok
            child_node -> set_parent(child_node, nil)
          end
        end

        Registry.unregister_node(node.id)
        :ok
    end
  end
end
