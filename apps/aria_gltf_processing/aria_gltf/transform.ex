# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Transform do
  @moduledoc """
  Transform utilities for aria-gltf, including rotation matrix conversions.
  
  Provides functions for converting between different rotation representations:
  - Tait-Bryan (Euler) angles
  - 3x3 rotation matrices
  - Quaternions (future)
  """

  @doc """
  Convert Tait-Bryan (Euler) angles to 3x3 rotation matrix.
  
  Uses ZYX convention: R = Rz(γ) * Ry(β) * Rx(α)
  Where:
  - α (alpha) = X rotation (pitch)
  - β (beta) = Y rotation (yaw)
  - γ (gamma) = Z rotation (roll)
  
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
    # Convert Tait-Bryan angles (in degrees) to 3x3 rotation matrix
    # Uses ZYX order (yaw-pitch-roll): R = Rz(γ) * Ry(β) * Rx(α)
    # Where: x = pitch (α), y = yaw (β), z = roll (γ)
    # This is the standard Tait-Bryan ZYX convention

    alpha = x_deg * :math.pi() / 180.0  # Pitch (X rotation)
    beta = y_deg * :math.pi() / 180.0   # Yaw (Y rotation)
    gamma = z_deg * :math.pi() / 180.0  # Roll (Z rotation)

    ca = :math.cos(alpha)
    sa = :math.sin(alpha)
    cb = :math.cos(beta)
    sb = :math.sin(beta)
    cg = :math.cos(gamma)
    sg = :math.sin(gamma)

    # Tait-Bryan ZYX rotation matrix: R = Rz(γ) * Ry(β) * Rx(α)
    # First row
    r11 = cb * cg
    r12 = -cb * sg
    r13 = sb

    # Second row
    r21 = sa * sb * cg + ca * sg
    r22 = -sa * sb * sg + ca * cg
    r23 = -sa * cb

    # Third row
    r31 = -ca * sb * cg + sa * sg
    r32 = ca * sb * sg + sa * cg
    r33 = ca * cb

    [
      [r11, r12, r13],
      [r21, r22, r23],
      [r31, r32, r33]
    ]
  end

  @doc """
  Convert 3x3 rotation matrix to Tait-Bryan (Euler) angles.
  
  Inverse of `euler_to_3x3_matrix/3`.
  Returns angles in degrees using ZYX convention.
  
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

    # Calculate yaw (β) from r13
    beta = :math.asin(:math.max(-1.0, :math.min(1.0, r13)))

    # Handle gimbal lock cases
    if abs(r13) >= 0.9999 do
      # Gimbal lock: beta ≈ ±90°
      alpha = 0.0
      gamma = :math.atan2(-r12, r11)
      {alpha * 180.0 / :math.pi(), beta * 180.0 / :math.pi(), gamma * 180.0 / :math.pi()}
    else
      # Normal case
      alpha = :math.atan2(-r23, r33)
      gamma = :math.atan2(-r12, r11)
      {alpha * 180.0 / :math.pi(), beta * 180.0 / :math.pi(), gamma * 180.0 / :math.pi()}
    end
  end
end

