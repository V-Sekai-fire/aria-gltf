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
      
      # For ZYX order with 90° X rotation: R = Rx(90°) * Ry(0°) * Rz(0°)
      # Result should be approximately [[1, 0, 0], [0, 0, 1], [0, -1, 0]]
      [[r11, r12, r13], [r21, r22, r23], [r31, r32, r33]] = matrix
      
      assert_in_delta r11, 1.0, 0.001
      assert_in_delta r12, 0.0, 0.001
      assert_in_delta r13, 0.0, 0.001
      assert_in_delta r21, 0.0, 0.001
      assert_in_delta r22, 0.0, 0.001
      assert_in_delta r23, 1.0, 0.001
      assert_in_delta r31, 0.0, 0.001
      assert_in_delta r32, -1.0, 0.001
      assert_in_delta r33, 0.0, 0.001
    end

  end
end

