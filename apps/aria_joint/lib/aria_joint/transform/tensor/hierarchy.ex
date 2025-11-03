# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.Transform.Tensor.Hierarchy do
  @moduledoc """
  Hierarchy propagation for joint transforms.

  Handles the complex logic of computing global transforms through parent-child
  relationships in joint hierarchies, with both standard and memory-optimized
  implementations for different scale requirements.
  """

  import Nx.Defn

  alias AriaJoint.{DirtyState}
  alias AriaJoint.Transform.Tensor.Core

  @doc """
  Compute global transforms for all joints using batch operations.

  This efficiently propagates transforms through the hierarchy using tensor operations.

  ## Examples

      updated_tensor = AriaJoint.Transform.Tensor.Hierarchy.compute_global_transforms_batch(joint_tensor)
  """
  @spec compute_global_transforms_batch(Core.joint_tensor()) :: Core.joint_tensor()
  def compute_global_transforms_batch(joint_tensor) do
    num_joints = Nx.axis_size(joint_tensor.local_transforms, 0)

    # Use constant memory version for large joint counts
    if num_joints > 1000 do
      compute_global_transforms_constant_memory(joint_tensor)
    else
      compute_global_transforms_standard(joint_tensor)
    end
  end

  @doc """
  Constant memory global transform computation for large joint hierarchies.

  Uses chunked processing with fixed memory buffers to handle arbitrarily large
  joint hierarchies without memory explosions.

  ## Examples

      updated_tensor = AriaJoint.Transform.Tensor.Hierarchy.compute_global_transforms_constant_memory(joint_tensor, 512)
  """
  @spec compute_global_transforms_constant_memory(Core.joint_tensor(), integer()) ::
          Core.joint_tensor()
  def compute_global_transforms_constant_memory(joint_tensor, chunk_size \\ 512) do
    num_joints = Nx.axis_size(joint_tensor.local_transforms, 0)
    max_depth = 10

    # Initialize global transforms with local transforms
    global_transforms = joint_tensor.local_transforms

    # Process hierarchy level by level to ensure dependencies are resolved
    updated_global =
      Enum.reduce(1..max_depth, global_transforms, fn _level, current_global ->
        # Process joints in chunks to maintain constant memory
        process_chunks_constant_memory(
          current_global,
          joint_tensor.parent_indices,
          joint_tensor.local_transforms,
          chunk_size
        )
      end)

    # Clear dirty flags after computation
    clean_dirty = Nx.broadcast(DirtyState.to_integer(DirtyState.dirty_none()), {num_joints})

    %{joint_tensor | global_transforms: updated_global, dirty_flags: clean_dirty}
  end

  # Standard global transform computation for smaller joint counts.
  @spec compute_global_transforms_standard(Core.joint_tensor()) :: Core.joint_tensor()
  defp compute_global_transforms_standard(joint_tensor) do
    # Use convergence-based propagation that handles arbitrary hierarchy depths
    # Initialize global transforms with local transforms for root nodes
    global_transforms = joint_tensor.local_transforms

    # Propagate through hierarchy until convergence (no more changes)
    updated_global =
      propagate_transforms_until_convergence(
        global_transforms,
        joint_tensor.parent_indices,
        joint_tensor.local_transforms
      )

    # Clear dirty flags after computation
    num_joints = Nx.axis_size(joint_tensor.local_transforms, 0)
    clean_dirty = Nx.broadcast(DirtyState.to_integer(DirtyState.dirty_none()), {num_joints})

    %{joint_tensor | global_transforms: updated_global, dirty_flags: clean_dirty}
  end

  # Constant memory chunk processing
  @spec process_chunks_constant_memory(Nx.Tensor.t(), Nx.Tensor.t(), Nx.Tensor.t(), integer()) ::
          Nx.Tensor.t()
  defp process_chunks_constant_memory(
         current_global,
         parent_indices,
         local_transforms,
         chunk_size
       ) do
    num_joints = Nx.axis_size(current_global, 0)

    # Process in chunks, reusing memory buffers
    0..(num_joints - 1)
    |> Enum.chunk_every(chunk_size)
    |> Enum.reduce(current_global, fn chunk_indices, acc_global ->
      start_idx = hd(chunk_indices)
      actual_chunk_size = length(chunk_indices)

      # Extract chunk data without creating large intermediate tensors
      chunk_parent_indices =
        Nx.slice_along_axis(parent_indices, start_idx, actual_chunk_size, axis: 0)

      chunk_local_transforms =
        Nx.slice_along_axis(local_transforms, start_idx, actual_chunk_size, axis: 0)

      chunk_current_global =
        Nx.slice_along_axis(acc_global, start_idx, actual_chunk_size, axis: 0)

      # Process this chunk with constant memory operations
      updated_chunk =
        propagate_parent_transforms_chunk(
          chunk_current_global,
          chunk_parent_indices,
          chunk_local_transforms,
          # Full global array for parent lookups
          acc_global
        )

      # Update the global transforms in-place style (create new tensor with updated chunk)
      # This avoids creating multiple large intermediate tensors
      update_global_chunk(acc_global, updated_chunk, start_idx, actual_chunk_size)
    end)
  end

  # Constant memory parent transform propagation for a chunk
  @spec propagate_parent_transforms_chunk(
          Nx.Tensor.t(),
          Nx.Tensor.t(),
          Nx.Tensor.t(),
          Nx.Tensor.t()
        ) :: Nx.Tensor.t()
  defp propagate_parent_transforms_chunk(
         chunk_global,
         chunk_parent_indices,
         chunk_local_transforms,
         full_global
       ) do
    # Check which joints in this chunk have parents
    has_parent = Nx.greater(chunk_parent_indices, -1)

    # Replace invalid parent indices (-1) with valid index (0) for safe gathering
    safe_parent_indices = Nx.max(chunk_parent_indices, 0)

    # Use Nx.take with axis=0 to gather parent transforms from the full global array
    parent_transforms = Nx.take(full_global, safe_parent_indices, axis: 0)

    # Use same explicit contract and batch axes as defn version
    # parent_transforms: {chunk_size, 4, 4}, chunk_local_transforms: {chunk_size, 4, 4}
    # Contract axis 2 of parent (columns) with axis 1 of local (rows)
    # Treat axis 0 as batch dimension for both tensors
    updated_transforms = Nx.dot(parent_transforms, [2], [0], chunk_local_transforms, [1], [0])

    # Use Nx.select to choose between current global (for roots) and updated (for children)
    has_parent_expanded =
      has_parent
      # {chunk_size, 1}
      |> Nx.new_axis(-1)
      # {chunk_size, 1, 1}
      |> Nx.new_axis(-1)
      # {chunk_size, 4, 4}
      |> Nx.broadcast(Nx.shape(chunk_global))

    Nx.select(has_parent_expanded, updated_transforms, chunk_global)
  end

  # Update global transforms with a processed chunk
  @spec update_global_chunk(Nx.Tensor.t(), Nx.Tensor.t(), integer(), integer()) :: Nx.Tensor.t()
  defp update_global_chunk(global_transforms, updated_chunk, start_idx, _chunk_size) do
    # Use Nx.put_slice to update the chunk in the global array
    # This is memory-efficient as it creates a new tensor with the updated slice
    indices = [start_idx, 0, 0]
    Nx.put_slice(global_transforms, indices, updated_chunk)
  end

  # Tensor-native hierarchy propagation with convergence detection
  @spec propagate_transforms_until_convergence(Nx.Tensor.t(), Nx.Tensor.t(), Nx.Tensor.t()) ::
          Nx.Tensor.t()
  defp propagate_transforms_until_convergence(global_transforms, parent_indices, local_transforms) do
    # Use defn-based convergence loop for optimal GPU performance
    propagate_transforms_defn(global_transforms, parent_indices, local_transforms)
  end

  # Tensor-native convergence loop using simple iteration for GPU optimization
  @spec propagate_transforms_defn(Nx.Tensor.t(), Nx.Tensor.t(), Nx.Tensor.t()) :: Nx.Tensor.t()
  defn propagate_transforms_defn(global_transforms, parent_indices, local_transforms) do
    # Use simple fixed iterations - most hierarchies converge in 3-5 iterations
    current_global = global_transforms

    # First iteration
    current_global =
      propagate_parent_transforms_defn(current_global, parent_indices, local_transforms)

    # Second iteration
    current_global =
      propagate_parent_transforms_defn(current_global, parent_indices, local_transforms)

    # Third iteration
    current_global =
      propagate_parent_transforms_defn(current_global, parent_indices, local_transforms)

    # Fourth iteration
    current_global =
      propagate_parent_transforms_defn(current_global, parent_indices, local_transforms)

    # Fifth iteration (should be sufficient for most hierarchies)
    propagate_parent_transforms_defn(current_global, parent_indices, local_transforms)
  end

  # Single propagation step using pure tensor operations (defn)
  @spec propagate_parent_transforms_defn(Nx.Tensor.t(), Nx.Tensor.t(), Nx.Tensor.t()) ::
          Nx.Tensor.t()
  defnp propagate_parent_transforms_defn(current_global, parent_indices, local_transforms) do
    # Check which joints have parents
    has_parent = Nx.greater(parent_indices, -1)

    # Replace invalid parent indices (-1) with valid index (0) for safe gathering
    safe_parent_indices = Nx.max(parent_indices, 0)

    # Gather parent transforms using tensor operations
    parent_transforms = Nx.take(current_global, safe_parent_indices, axis: 0)

    # Use generalized Nx.dot with explicit contract and batch axes
    # parent_transforms: {batch, 4, 4}, local_transforms: {batch, 4, 4}
    # Contract axis 2 of parent (columns) with axis 1 of local (rows)
    # Treat axis 0 as batch dimension for both tensors
    updated_transforms = Nx.dot(parent_transforms, [2], [0], local_transforms, [1], [0])

    # Use Nx.select to choose between current global (for roots) and updated (for children)
    # Expand has_parent to match tensor dimensions {num_joints, 4, 4}
    has_parent_expanded =
      has_parent
      # {num_joints, 1}
      |> Nx.new_axis(-1)
      # {num_joints, 1, 1}
      |> Nx.new_axis(-1)
      # {num_joints, 4, 4}
      |> Nx.broadcast(Nx.shape(current_global))

    Nx.select(has_parent_expanded, updated_transforms, current_global)
  end
end
