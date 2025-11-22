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

  alias Nx
  alias AriaMath.{Matrix4.Euler, Matrix4.Core, Matrix4.Transformations}

  @type matrix_3x3() :: [list(float())]

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
      [[1.0, 0.0, 0.0], [0.0, 0.0, 1.0], [0.0, -1.0, 0.0]]
  """
  @spec euler_to_3x3_matrix(float(), float(), float()) :: matrix_3x3()
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

end
