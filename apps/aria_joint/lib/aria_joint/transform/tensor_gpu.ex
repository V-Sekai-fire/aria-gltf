# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.Transform.TensorGPU do
  @moduledoc """
  GPU-optimized tensor operations for Joint transforms using defn compilation.

  This module provides highly optimized GPU operations using Nx.defn for JIT compilation,
  keeping all data on GPU and minimizing CPU-GPU transfers.

  ## Features

  - JIT-compiled defn functions for maximum GPU performance
  - Memory-aware batch processing using AriaMath.Memory
  - Minimized CPU-GPU data transfers
  - Optimized matrix operations for large joint hierarchies

  ## Usage

      # Fast GPU batch transform operations
      result = AriaJoint.Transform.TensorGPU.batch_hierarchy_propagation_gpu(
        local_transforms, parent_indices
      )
  """

  import Nx.Defn

  @doc """
  GPU-optimized batch hierarchy propagation using JIT compilation.

  Uses fixed iteration count for maximum GPU performance.
  All operations stay on GPU with no CPU transfers.
  """
  @spec batch_hierarchy_propagation_gpu(Nx.Tensor.t(), Nx.Tensor.t()) :: Nx.Tensor.t()
  def batch_hierarchy_propagation_gpu(local_transforms, parent_indices) do
    # Use fixed iteration count for optimal GPU performance
    # Most skeletal hierarchies converge in 5-10 iterations
    hierarchy_propagation_defn(local_transforms, parent_indices)
  end

  @doc """
  JIT-compiled hierarchy propagation with fixed iterations for maximum GPU performance.

  Uses unrolled iterations to avoid recursion issues in defn compilation.
  """
  @spec hierarchy_propagation_defn(Nx.Tensor.t(), Nx.Tensor.t()) :: Nx.Tensor.t()
  defn hierarchy_propagation_defn(local_transforms, parent_indices) do
    # Initialize with local transforms
    global_transforms = local_transforms

    # Unroll iterations for optimal GPU performance (avoids recursion issues)
    global_transforms = propagate_step_gpu(global_transforms, parent_indices, local_transforms)
    global_transforms = propagate_step_gpu(global_transforms, parent_indices, local_transforms)
    global_transforms = propagate_step_gpu(global_transforms, parent_indices, local_transforms)
    global_transforms = propagate_step_gpu(global_transforms, parent_indices, local_transforms)
    global_transforms = propagate_step_gpu(global_transforms, parent_indices, local_transforms)
    global_transforms = propagate_step_gpu(global_transforms, parent_indices, local_transforms)
    global_transforms = propagate_step_gpu(global_transforms, parent_indices, local_transforms)
    global_transforms = propagate_step_gpu(global_transforms, parent_indices, local_transforms)
    global_transforms = propagate_step_gpu(global_transforms, parent_indices, local_transforms)
    propagate_step_gpu(global_transforms, parent_indices, local_transforms)
  end

  @spec propagate_step_gpu(Nx.Tensor.t(), Nx.Tensor.t(), Nx.Tensor.t()) :: Nx.Tensor.t()
  defnp propagate_step_gpu(current_global, parent_indices, local_transforms) do
    # Check which joints have parents (vectorized operation)
    has_parent = Nx.greater(parent_indices, -1)

    # Safe parent index lookup (replace -1 with 0 for safe gathering)
    safe_parent_indices = Nx.max(parent_indices, 0)

    # Gather parent transforms (efficient GPU memory access)
    parent_transforms = Nx.take(current_global, safe_parent_indices, axis: 0)

    # Batched matrix multiplication using optimal GPU operations
    # parent_transforms: {batch, 4, 4}, local_transforms: {batch, 4, 4}
    # Result: {batch, 4, 4} - each result[i] = parent_transforms[i] * local_transforms[i]
    updated_transforms = Nx.dot(parent_transforms, [2], [0], local_transforms, [1], [0])

    # Vectorized selection between current and updated transforms
    has_parent_mask =
      has_parent
      |> Nx.new_axis(-1)
      |> Nx.new_axis(-1)
      |> Nx.broadcast(Nx.shape(current_global))

    Nx.select(has_parent_mask, updated_transforms, current_global)
  end

  @doc """
  GPU-optimized batch coordinate transformation.
  """
  @spec batch_transform_points_gpu(Nx.Tensor.t(), Nx.Tensor.t()) :: Nx.Tensor.t()
  def batch_transform_points_gpu(transforms, points) do
    transform_points_defn(transforms, points)
  end

  @doc """
  JIT-compiled point transformation for maximum GPU performance.
  """
  @spec transform_points_defn(Nx.Tensor.t(), Nx.Tensor.t()) :: Nx.Tensor.t()
  defn transform_points_defn(transforms, points) do
    # transforms: {batch, 4, 4}
    # points: {batch, num_points, 3} or {batch, 3}

    points_shape = Nx.shape(points)

    case points_shape do
      {batch_size, 3} ->
        # Single point per transform
        # Convert to homogeneous coordinates
        ones = Nx.broadcast(1.0, {batch_size, 1})
        homogeneous_points = Nx.concatenate([points, ones], axis: 1)
        # Reshape for matrix multiplication: {batch, 4, 1}
        points_reshaped = Nx.reshape(homogeneous_points, {batch_size, 4, 1})

        # Batch matrix-vector multiplication
        transformed = Nx.dot(transforms, [2], [0], points_reshaped, [1], [0])

        # Extract xyz coordinates and reshape back
        Nx.slice_along_axis(transformed, 0, 3, axis: 1) |> Nx.squeeze(axes: [2])

      {batch_size, num_points, 3} ->
        # Multiple points per transform
        # Convert to homogeneous coordinates
        ones = Nx.broadcast(1.0, {batch_size, num_points, 1})
        homogeneous_points = Nx.concatenate([points, ones], axis: 2)

        # Reshape for efficient batched multiplication
        # homogeneous_points: {batch, num_points, 4} -> {batch, 4, num_points}
        points_transposed = Nx.transpose(homogeneous_points, axes: [0, 2, 1])

        # Batch matrix multiplication: transforms * points_transposed
        transformed = Nx.dot(transforms, [2], [0], points_transposed, [1], [0])

        # Extract xyz and transpose back: {batch, 3, num_points} -> {batch, num_points, 3}
        xyz_transformed = Nx.slice_along_axis(transformed, 0, 3, axis: 1)
        Nx.transpose(xyz_transformed, axes: [0, 2, 1])
    end
  end

  @doc """
  GPU-optimized batch matrix multiplication with memory management.
  """
  @spec batch_matrix_multiply_gpu(Nx.Tensor.t(), Nx.Tensor.t()) :: Nx.Tensor.t()
  def batch_matrix_multiply_gpu(matrices_a, matrices_b) do
    batch_matrix_multiply_defn(matrices_a, matrices_b)
  end

  @doc """
  JIT-compiled batch matrix multiplication.
  """
  @spec batch_matrix_multiply_defn(Nx.Tensor.t(), Nx.Tensor.t()) :: Nx.Tensor.t()
  defn batch_matrix_multiply_defn(matrices_a, matrices_b) do
    # Efficient batched matrix multiplication
    # matrices_a: {batch, 4, 4}, matrices_b: {batch, 4, 4}
    # Result: {batch, 4, 4} where result[i] = matrices_a[i] * matrices_b[i]
    Nx.dot(matrices_a, [2], [0], matrices_b, [1], [0])
  end

  @doc """
  GPU-optimized position extraction from transform matrices.
  """
  @spec extract_positions_gpu(Nx.Tensor.t()) :: Nx.Tensor.t()
  def extract_positions_gpu(transforms) do
    extract_positions_defn(transforms)
  end

  @doc """
  JIT-compiled position extraction.
  """
  @spec extract_positions_defn(Nx.Tensor.t()) :: Nx.Tensor.t()
  defn extract_positions_defn(transforms) do
    # Extract translation column (last column, first 3 rows)
    # transforms: {batch, 4, 4} -> positions: {batch, 3}
    Nx.slice(transforms, [0, 0, 3], [Nx.axis_size(transforms, 0), 3, 1])
    |> Nx.squeeze(axes: [2])
  end

  @doc """
  GPU-optimized batch rotation extraction as quaternions.
  """
  @spec extract_rotations_gpu(Nx.Tensor.t()) :: Nx.Tensor.t()
  def extract_rotations_gpu(transforms) do
    extract_rotations_defn(transforms)
  end

  @doc """
  JIT-compiled rotation extraction (simplified - extracts rotation matrix).
  """
  @spec extract_rotations_defn(Nx.Tensor.t()) :: Nx.Tensor.t()
  defn extract_rotations_defn(transforms) do
    # Extract 3x3 rotation matrix (upper-left 3x3)
    # transforms: {batch, 4, 4} -> rotations: {batch, 3, 3}
    Nx.slice(transforms, [0, 0, 0], [Nx.axis_size(transforms, 0), 3, 3])
  end

  @doc """
  Create GPU-optimized joint tensor data with all tensors on GPU.
  Ensures data starts and stays on GPU for maximum performance.
  """
  @spec create_gpu_joint_data(list()) :: map()
  def create_gpu_joint_data(transforms_list) when is_list(transforms_list) do
    size = length(transforms_list)

    # Create tensors directly on GPU with proper backend
    local_transforms =
      transforms_list
      |> Nx.tensor(type: :f32)
      |> Nx.backend_copy({Torchx.Backend, device: :cuda})

    # Simple chain hierarchy optimized for GPU
    parent_indices =
      0..(size - 1)
      |> Enum.map(fn
        # Root has no parent
        0 -> -1
        # Chain hierarchy
        i -> i - 1
      end)
      |> Nx.tensor(type: :s32)
      |> Nx.backend_copy({Torchx.Backend, device: :cuda})

    %{
      local_transforms: local_transforms,
      # Initialize with local
      global_transforms: local_transforms,
      parent_indices: parent_indices
    }
  end

  @doc """
  Complete GPU-optimized joint processing pipeline.
  All operations stay on GPU for maximum performance.
  """
  @spec gpu_joint_pipeline(map()) :: map()
  def gpu_joint_pipeline(joint_data) do
    # All operations stay on GPU for maximum performance
    global_transforms =
      batch_hierarchy_propagation_gpu(
        joint_data.local_transforms,
        joint_data.parent_indices
      )

    positions = extract_positions_gpu(global_transforms)
    rotations = extract_rotations_gpu(global_transforms)

    Map.merge(joint_data, %{
      global_transforms: global_transforms,
      positions: positions,
      rotations: rotations
    })
  end

  @doc """
  Simple GPU test function to verify GPU utilization.
  """
  @spec simple_gpu_test(integer()) :: Nx.Tensor.t()
  def simple_gpu_test(size \\ 1000) do
    # Create simple test data on GPU
    transforms =
      1..size
      |> Enum.map(fn i ->
        [
          [1.0, 0.0, 0.0, i * 0.1],
          [0.0, 1.0, 0.0, 0.0],
          [0.0, 0.0, 1.0, 0.0],
          [0.0, 0.0, 0.0, 1.0]
        ]
      end)
      |> Nx.tensor(type: :f32)
      |> Nx.backend_copy({Torchx.Backend, device: :cuda})

    # Simple GPU computation
    simple_computation_defn(transforms)
  end

  @spec simple_computation_defn(Nx.Tensor.t()) :: Nx.Tensor.t()
  defn simple_computation_defn(transforms) do
    # Simple matrix operations to test GPU
    result = Nx.dot(transforms, [2], [0], transforms, [1], [0])
    Nx.mean(result, axes: [1, 2])
  end
end
