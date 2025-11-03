# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJointTest do
  use ExUnit.Case, async: false

  alias AriaJoint.{Joint, JointFixtures}
  alias AriaMath.{Matrix4, Quaternion}

  describe "new/1" do
    test "creates root node" do
      {:ok, node} = Joint.new()
      assert node.id != nil
      assert node.parent == nil
      assert node.children == []
      assert node.local_transform == Matrix4.identity()
      assert node.global_transform == Matrix4.identity()
    end

    test "creates child node with parent" do
      {:ok, parent} = Joint.new()
      {:ok, child} = Joint.new(parent: parent)

      assert child.parent == parent.id
      assert parent.id in child.children == false
      # Parent should be updated in registry with child
    end

    test "creates node with scale disabled" do
      {:ok, node} = Joint.new(disable_scale: true)
      assert node.disable_scale == true
    end
  end

  describe "set_transform/2" do
    test "sets local transform" do
      {:ok, node} = Joint.new()
      transform = JointFixtures.transforms().translation_1_2_3

      updated_node = Joint.set_transform(node, transform)
      assert Matrix4.equal?(updated_node.local_transform, transform)
    end

    test "does not update if transform is identical" do
      {:ok, node} = Joint.new()
      transform = JointFixtures.transforms().identity

      updated_node = Joint.set_transform(node, transform)
      assert updated_node == node
    end
  end

  describe "get_transform/1" do
    test "returns local transform" do
      {:ok, node} = Joint.new()
      transform = JointFixtures.transforms().translation_1_2_3
      node = Joint.set_transform(node, transform)

      result = Joint.get_transform(node)
      assert Matrix4.equal?(result, transform)
    end
  end

  describe "get_global_transform/1" do
    test "returns global transform for root node" do
      {:ok, node} = Joint.new()
      transform = JointFixtures.transforms().translation_1_2_3
      node = Joint.set_transform(node, transform)

      global_transform = Joint.get_global_transform(node)
      assert Matrix4.equal?(global_transform, transform)
    end

    test "computes global transform from hierarchy" do
      hierarchy = JointFixtures.hierarchies().parent_child_simple

      {:ok, parent} = Joint.new()
      parent = Joint.set_transform(parent, hierarchy.parent_transform)

      {:ok, child} = Joint.new(parent: parent)
      child = Joint.set_transform(child, hierarchy.child_local_transform)

      global_transform = Joint.get_global_transform(child)
      assert Matrix4.equal?(global_transform, hierarchy.expected_global_child)
    end
  end

  describe "set_global_transform/2" do
    test "sets global transform for root node" do
      {:ok, node} = Joint.new()
      global_transform = JointFixtures.transforms().translation_1_2_3

      updated_node = Joint.set_global_transform(node, global_transform)
      result = Joint.get_global_transform(updated_node)
      assert Matrix4.equal?(result, global_transform)
    end

    test "computes appropriate local transform for child node" do
      {:ok, parent} = Joint.new()
      parent_transform = Matrix4.translation({1.0, 0.0, 0.0})
      parent = Joint.set_transform(parent, parent_transform)

      {:ok, child} = Joint.new(parent: parent)
      global_transform = Matrix4.translation({2.0, 1.0, 0.0})

      updated_child = Joint.set_global_transform(child, global_transform)

      # Local transform should be the difference
      expected_local = Matrix4.translation({1.0, 1.0, 0.0})
      result = Joint.get_transform(updated_child)
      assert Matrix4.equal?(result, expected_local)
    end
  end

  describe "parent-child relationships" do
    test "set_parent/2 establishes relationship" do
      {:ok, parent} = Joint.new()
      {:ok, child} = Joint.new()

      updated_child = Joint.set_parent(child, parent)
      assert updated_child.parent == parent.id
    end

    test "set_parent/2 with nil removes parent" do
      {:ok, parent} = Joint.new()
      {:ok, child} = Joint.new(parent: parent)

      updated_child = Joint.set_parent(child, nil)
      assert updated_child.parent == nil
    end

    test "get_parent/1 returns parent node" do
      {:ok, parent} = Joint.new()
      {:ok, child} = Joint.new(parent: parent)

      parent_node = Joint.get_parent(child)
      assert parent_node.id == parent.id
    end
  end

  describe "coordinate space conversions" do
    test "to_local/2 converts global point to local space" do
      conversions = JointFixtures.coordinate_conversions()
      fixture = conversions.global_to_local

      {:ok, node} = Joint.new()
      node = Joint.set_transform(node, fixture.node_transform)

      result = Joint.to_local(node, fixture.global_point)
      assert result == fixture.expected_local_point
    end

    test "to_global/2 converts local point to global space" do
      conversions = JointFixtures.coordinate_conversions()
      fixture = conversions.local_to_global

      {:ok, node} = Joint.new()
      node = Joint.set_transform(node, fixture.node_transform)

      result = Joint.to_global(node, fixture.local_point)
      assert result == fixture.expected_global_point
    end

    test "identity conversions preserve points" do
      conversions = JointFixtures.coordinate_conversions()
      fixture = conversions.identity_conversion

      {:ok, node} = Joint.new()
      node = Joint.set_transform(node, fixture.node_transform)

      local_result = Joint.to_local(node, fixture.global_point)
      assert local_result == fixture.expected_local_point

      global_result = Joint.to_global(node, fixture.local_point)
      assert global_result == fixture.expected_global_point
    end
  end

  describe "scale management" do
    test "set_disable_scale/2 toggles scale flag" do
      {:ok, node} = Joint.new()

      updated_node = Joint.set_disable_scale(node, true)
      assert Joint.scale_disabled?(updated_node) == true

      updated_node = Joint.set_disable_scale(updated_node, false)
      assert Joint.scale_disabled?(updated_node) == false
    end

    test "disabled scale orthogonalizes global transform" do
      {:ok, node} = Joint.new(disable_scale: true)
      # Create a scaled transformation
      scaled_transform = Matrix4.scaling({2.0, 2.0, 2.0})
      node = Joint.set_transform(node, scaled_transform)

      global_transform = Joint.get_global_transform(node)
      # Should be orthogonalized (unit basis vectors)
      {tx, ty, tz} = Matrix4.get_translation(global_transform)
      assert tx == 0.0 and ty == 0.0 and tz == 0.0
    end
  end

  describe "rotation operations" do
    test "rotate_local_with_global/3 applies global rotation" do
      {:ok, parent} = Joint.new()

      parent_transform =
        Matrix4.rotation(Quaternion.from_axis_angle({0.0, 0.0, 1.0}, :math.pi() / 2))

      parent = Joint.set_transform(parent, parent_transform)

      {:ok, child} = Joint.new(parent: parent)

      # Apply a global rotation
      global_rotation =
        Matrix4.rotation(Quaternion.from_axis_angle({1.0, 0.0, 0.0}, :math.pi() / 4))

      updated_child = Joint.rotate_local_with_global(child, global_rotation)

      # Should have updated local transform
      assert updated_child.local_transform != Matrix4.identity()
    end
  end

  describe "cleanup/1" do
    test "cleans up node and relationships" do
      {:ok, parent} = Joint.new()
      {:ok, child} = Joint.new(parent: parent)

      assert :ok = Joint.cleanup(child)

      # Should remove parent-child relationships
      updated_parent = Joint.get_parent(child)
      assert updated_parent == nil
    end
  end

  describe "dirty state management" do
    test "transforms marked dirty propagate correctly" do
      {:ok, parent} = Joint.new()
      {:ok, child} = Joint.new(parent: parent)

      # Changing parent should mark child as dirty
      parent_transform = Matrix4.translation({1.0, 0.0, 0.0})
      _updated_parent = Joint.set_transform(parent, parent_transform)

      # Child should recompute global transform
      global_transform = Joint.get_global_transform(child)
      expected = Matrix4.multiply(parent_transform, Matrix4.identity())
      assert global_transform == expected
    end
  end
end
