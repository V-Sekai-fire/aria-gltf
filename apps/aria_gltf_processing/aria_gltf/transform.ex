# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Transform do
  @moduledoc """
  Transform utilities for aria-gltf, including rotation matrix conversions.
  
  Provides functions for converting between different rotation representations:
  - Tait-Bryan (Euler) angles
  - 3x3 rotation matrices
  
  This module integrates with `AriaMath.Matrix4.Euler` for Euler angle operations
  and `AriaMath.Matrix4.Transformations` for matrix operations.
  """

  alias AriaMath.{Matrix4.Euler, Matrix4.Core, Matrix4.Transformations}

  @doc """
  Convert Tait-Bryan (Euler) angles to 3x3 rotation matrix.
  
  Uses ZYX convention (Tait-Bryan order) via `AriaMath.Matrix4.Euler`.
  This is the standard convention used by many 3D engines.
  
  ## Parameters
  
  - `x_deg`: Pitch angle in degrees (rotation around X-axis)
  - `y_deg`: Yaw angle in degrees (rotation around Y-axis)
  - `z_deg`: Roll angle in degrees (rotation around Z-axis)
  
  ## Returns
  
  3x3 rotation matrix as a list of lists:
  ```elixir
  [[r11, r12, r13],
   [r21, r22, r23],
   [r31, r32, r33]]
  ```
  
  ## Examples
  
      iex> AriaGltf.Transform.euler_to_3x3_matrix(0, 0, 0)
      [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
      
      iex> matrix = AriaGltf.Transform.euler_to_3x3_matrix(90, 0, 0)
      [[1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0]]
  """
  @spec euler_to_3x3_matrix(float(), float(), float()) ::
          [[float(), float(), float()], [float(), float(), float()], [float(), float(), float()]]
  def euler_to_3x3_matrix(x_deg, y_deg, z_deg) do
    # Convert degrees to radians
    x_rad = x_deg * :math.pi() / 180.0
    y_rad = y_deg * :math.pi() / 180.0
    z_rad = z_deg * :math.pi() / 180.0

    # Use AriaMath.Matrix4.Euler to create 4x4 rotation matrix with ZYX order
    matrix4_tuple = Euler.from_euler(x_rad, y_rad, z_rad, :zyx)

    # Convert tuple to Nx tensor
    matrix4_tensor = Core.from_tuple(matrix4_tuple)

    # Extract 3x3 basis matrix (upper-left corner)
    basis_3x3 = Transformations.extract_basis(matrix4_tensor)

    # Convert Nx tensor to list of lists
    Nx.to_list(basis_3x3)
  end

  @doc """
  Convert 3x3 rotation matrix to Tait-Bryan (Euler) angles.
  
  Inverse of `euler_to_3x3_matrix/3`.
  Returns angles in degrees using ZYX convention.
  
  This implements the inverse of the ZYX rotation order:
  R = Rz(γ) * Ry(β) * Rx(α)
  
  ## Parameters
  
  - `matrix`: 3x3 rotation matrix as list of lists
  
  ## Returns
  
  `{x_deg, y_deg, z_deg}` tuple of angles in degrees
  
  ## Examples
  
      iex> matrix = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
      iex> AriaGltf.Transform.matrix_3x3_to_euler(matrix)
      {0.0, 0.0, 0.0}
  """
  @spec matrix_3x3_to_euler([[float(), float(), float()], [float(), float(), float()], [float(), float(), float()]]) ::
          {float(), float(), float()}
  def matrix_3x3_to_euler([
        [r11, r12, r13],
        [r21, r22, r23],
        [r31, r32, r33]
      ]) do
    # Extract Tait-Bryan angles from 3x3 rotation matrix
    # Using ZYX convention: R = Rz(γ) * Ry(β) * Rx(α)
    # Where: α = pitch (X), β = yaw (Y), γ = roll (Z)

    # Calculate yaw (β) from r13
    # r13 = sin(β) in ZYX order
    beta = :math.asin(:math.max(-1.0, :math.min(1.0, r13)))

    # Handle gimbal lock cases (when |sin(β)| ≈ 1, i.e., β ≈ ±90°)
    if abs(r13) >= 0.9999 do
      # Gimbal lock: beta ≈ ±90°
      # In this case, we can only determine α + γ, so we set α = 0
      alpha = 0.0
      gamma = :math.atan2(-r12, r11)
      {alpha * 180.0 / :math.pi(), beta * 180.0 / :math.pi(), gamma * 180.0 / :math.pi()}
    else
      # Normal case: extract all three angles
      # From ZYX rotation matrix:
      # r23 = -sin(α) * cos(β)
      # r33 = cos(α) * cos(β)
      # r12 = -cos(β) * sin(γ)
      # r11 = cos(β) * cos(γ)
      alpha = :math.atan2(-r23, r33)
      gamma = :math.atan2(-r12, r11)
      {alpha * 180.0 / :math.pi(), beta * 180.0 / :math.pi(), gamma * 180.0 / :math.pi()}
    end
  end
end
