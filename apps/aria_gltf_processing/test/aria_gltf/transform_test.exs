# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.TransformTest do
  use ExUnit.Case
  alias AriaGltf.Transform

  describe "euler_to_3x3_matrix/3" do
    test "converts zero angles to identity matrix" do
      matrix = Transform.euler_to_3x3_matrix(0.0, 0.0, 0.0)
      
      assert matrix == [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0]
      ]
    end

    test "converts 90 degree X rotation" do
      matrix = Transform.euler_to_3x3_matrix(90.0, 0.0, 0.0)
      
      # Should be approximately [[1, 0, 0], [0, 0, -1], [0, 1, 0]]
      [[r11, r12, r13], [r21, r22, r23], [r31, r32, r33]] = matrix
      
      assert_in_delta r11, 1.0, 0.001
      assert_in_delta r12, 0.0, 0.001
      assert_in_delta r13, 0.0, 0.001
      assert_in_delta r21, 0.0, 0.001
      assert_in_delta r22, 0.0, 0.001
      assert_in_delta r23, -1.0, 0.001
      assert_in_delta r31, 0.0, 0.001
      assert_in_delta r32, 1.0, 0.001
      assert_in_delta r33, 0.0, 0.001
    end

    test "round-trip conversion" do
      angles = {45.0, 30.0, 60.0}
      {x, y, z} = angles
      
      matrix = Transform.euler_to_3x3_matrix(x, y, z)
      {x_back, y_back, z_back} = Transform.matrix_3x3_to_euler(matrix)
      
      assert_in_delta x, x_back, 0.1
      assert_in_delta y, y_back, 0.1
      assert_in_delta z, z_back, 0.1
    end
  end

  describe "matrix_3x3_to_euler/1" do
    test "converts identity matrix to zero angles" do
      matrix = [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0]
      ]
      
      {x, y, z} = Transform.matrix_3x3_to_euler(matrix)
      
      assert_in_delta x, 0.0, 0.001
      assert_in_delta y, 0.0, 0.001
      assert_in_delta z, 0.0, 0.001
    end
  end
end

