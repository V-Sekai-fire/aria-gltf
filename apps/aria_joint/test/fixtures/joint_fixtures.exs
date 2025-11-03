# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.JointFixtures do
  @moduledoc """
  Golden standard fixtures for Joint operations.

  These fixtures define expected results for Joint transform operations
  to ensure correctness without relying on debug logging.
  """

  alias AriaMath.Matrix4

  @doc """
  Simple transform fixtures for basic Joint operations.
  """
  def transforms do
    %{
      # Translation by (1, 2, 3)
      translation_1_2_3: Matrix4.translation({1.0, 2.0, 3.0}),

      # Identity transform
      identity: Matrix4.identity()
    }
  end

  @doc """
  Transform hierarchy fixtures.
  """
  def hierarchies do
    %{
      # Parent at (1,0,0), child at (0,1,0) relative to parent
      # Expected global child position: (1,1,0)
      parent_child_simple: %{
        parent_transform: Matrix4.translation({1.0, 0.0, 0.0}),
        child_local_transform: Matrix4.translation({0.0, 1.0, 0.0}),
        expected_global_child: Matrix4.translation({1.0, 1.0, 0.0})
      },

      # Root at origin, child at (1,2,3)
      root_child: %{
        parent_transform: Matrix4.identity(),
        child_local_transform: Matrix4.translation({1.0, 2.0, 3.0}),
        expected_global_child: Matrix4.translation({1.0, 2.0, 3.0})
      },

      # Complex hierarchy: grandparent -> parent -> child
      three_level: %{
        grandparent_transform: Matrix4.translation({1.0, 0.0, 0.0}),
        parent_local_transform: Matrix4.translation({0.0, 1.0, 0.0}),
        child_local_transform: Matrix4.translation({0.0, 0.0, 1.0}),
        expected_global_parent: Matrix4.translation({1.0, 1.0, 0.0}),
        expected_global_child: Matrix4.translation({1.0, 1.0, 1.0})
      }
    }
  end

  @doc """
  Coordinate space conversion fixtures.
  """
  def coordinate_conversions do
    %{
      # Node at (1,2,3), global point (2,3,4) -> local point (1,1,1)
      global_to_local: %{
        node_transform: Matrix4.translation({1.0, 2.0, 3.0}),
        global_point: {2.0, 3.0, 4.0},
        expected_local_point: {1.0, 1.0, 1.0}
      },

      # Node at (1,2,3), local point (1,1,1) -> global point (2,3,4)
      local_to_global: %{
        node_transform: Matrix4.translation({1.0, 2.0, 3.0}),
        local_point: {1.0, 1.0, 1.0},
        expected_global_point: {2.0, 3.0, 4.0}
      },

      # Identity transform: point should remain unchanged
      identity_conversion: %{
        node_transform: Matrix4.identity(),
        global_point: {1.0, 2.0, 3.0},
        expected_local_point: {1.0, 2.0, 3.0},
        local_point: {1.0, 2.0, 3.0},
        expected_global_point: {1.0, 2.0, 3.0}
      }
    }
  end

  @doc """
  Scale management fixtures.
  """
  def scale_management do
    %{
      # Scaled transform that should be orthogonalized when scale is disabled
      scaled_transform: Matrix4.scaling({2.0, 2.0, 2.0}),

      # Expected orthogonalized result (unit vectors, zero translation)
      orthogonalized_result: %{
        translation: {0.0, 0.0, 0.0},
        # Unit basis vectors
        basis_vectors: [
          {1.0, 0.0, 0.0},
          {0.0, 1.0, 0.0},
          {0.0, 0.0, 1.0}
        ]
      }
    }
  end
end
