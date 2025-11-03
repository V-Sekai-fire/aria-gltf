# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.NestedSetTest do
  use ExUnit.Case, async: true

  alias AriaJoint.{Joint, NestedSet, HierarchyManager}
  alias AriaMath.Matrix4

  describe "NestedSet.build_nested_set/1" do
    test "builds correct nested set for single node" do
      {:ok, root} = Joint.new()
      nested_set = NestedSet.build_nested_set([root])

      assert nested_set.size == 1
      assert Map.get(nested_set.offset_to_node_id, 0) == root.id

      metadata = Map.get(nested_set.node_id_to_metadata, root.id)
      assert metadata.offset == 0
      assert metadata.span == 1
    end

    test "builds correct nested set for chain hierarchy" do
      {:ok, root} = Joint.new()
      {:ok, child1} = Joint.new(parent: root)
      {:ok, child2} = Joint.new(parent: child1)

      nested_set = NestedSet.build_nested_set([root])

      assert nested_set.size == 3

      # Check root node (should contain entire tree)
      root_metadata = Map.get(nested_set.node_id_to_metadata, root.id)
      assert root_metadata.offset == 0
      assert root_metadata.span == 3

      # Check that all nodes are represented
      assert map_size(nested_set.node_id_to_metadata) == 3
      assert map_size(nested_set.offset_to_node_id) == 3

      # Clean up
      Joint.cleanup(child2)
      Joint.cleanup(child1)
      Joint.cleanup(root)
    end

    test "builds correct nested set for tree hierarchy" do
      {:ok, root} = Joint.new()
      {:ok, left_child} = Joint.new(parent: root)
      {:ok, right_child} = Joint.new(parent: root)
      {:ok, grandchild} = Joint.new(parent: left_child)

      nested_set = NestedSet.build_nested_set([root])

      assert nested_set.size == 4

      # Root should have span of 4 (entire tree)
      root_metadata = Map.get(nested_set.node_id_to_metadata, root.id)
      assert root_metadata.offset == 0
      assert root_metadata.span == 4

      # All nodes should be represented
      assert map_size(nested_set.node_id_to_metadata) == 4

      # Clean up
      Joint.cleanup(grandchild)
      Joint.cleanup(right_child)
      Joint.cleanup(left_child)
      Joint.cleanup(root)
    end
  end

  describe "NestedSet.mark_subtree_dirty/3" do
    test "marks single node as dirty" do
      {:ok, root} = Joint.new()
      nested_set = NestedSet.build_nested_set([root])

      updated_nested_set = NestedSet.mark_subtree_dirty(nested_set, root.id)

      assert Map.get(updated_nested_set.dirty_flags, 0) == true

      Joint.cleanup(root)
    end

    test "marks entire subtree as dirty" do
      {:ok, root} = Joint.new()
      {:ok, child1} = Joint.new(parent: root)
      {:ok, child2} = Joint.new(parent: child1)

      nested_set = NestedSet.build_nested_set([root])

      # Mark root subtree dirty (should mark all nodes)
      updated_nested_set = NestedSet.mark_subtree_dirty(nested_set, root.id)

      # All offsets should be marked dirty
      assert Map.get(updated_nested_set.dirty_flags, 0) == true
      assert Map.get(updated_nested_set.dirty_flags, 1) == true
      assert Map.get(updated_nested_set.dirty_flags, 2) == true

      # Clean up
      Joint.cleanup(child2)
      Joint.cleanup(child1)
      Joint.cleanup(root)
    end

    test "marks partial subtree as dirty" do
      {:ok, root} = Joint.new()
      {:ok, left_child} = Joint.new(parent: root)
      {:ok, right_child} = Joint.new(parent: root)
      {:ok, grandchild} = Joint.new(parent: left_child)

      nested_set = NestedSet.build_nested_set([root])

      # Get left child metadata
      left_metadata = Map.get(nested_set.node_id_to_metadata, left_child.id)

      # Mark left child subtree dirty (should include grandchild but not right child)
      updated_nested_set = NestedSet.mark_subtree_dirty(nested_set, left_child.id)

      # Check that left child's span is marked dirty
      for offset <- left_metadata.offset..(left_metadata.offset + left_metadata.span - 1) do
        assert Map.get(updated_nested_set.dirty_flags, offset) == true
      end

      # Clean up
      Joint.cleanup(grandchild)
      Joint.cleanup(right_child)
      Joint.cleanup(left_child)
      Joint.cleanup(root)
    end

    test "skips marking if already dirty (optimization)" do
      {:ok, root} = Joint.new()
      nested_set = NestedSet.build_nested_set([root])

      # Mark dirty once
      updated_nested_set = NestedSet.mark_subtree_dirty(nested_set, root.id)

      # Mark dirty again (should be no-op due to optimization)
      final_nested_set = NestedSet.mark_subtree_dirty(updated_nested_set, root.id)

      # Should be identical
      assert final_nested_set == updated_nested_set

      Joint.cleanup(root)
    end
  end

  describe "NestedSet.get_dirty_range/1" do
    test "returns empty list when no nodes are dirty" do
      {:ok, root} = Joint.new()
      nested_set = NestedSet.build_nested_set([root])

      # Clear all dirty flags
      clean_nested_set = %{
        nested_set
        | dirty_flags: Map.new(nested_set.dirty_flags, fn {k, _v} -> {k, false} end)
      }

      dirty_nodes = NestedSet.get_dirty_range(clean_nested_set)
      assert dirty_nodes == []

      Joint.cleanup(root)
    end

    test "returns dirty nodes in nested set order" do
      {:ok, root} = Joint.new()
      {:ok, child1} = Joint.new(parent: root)
      {:ok, child2} = Joint.new(parent: child1)

      nested_set = NestedSet.build_nested_set([root])
      updated_nested_set = NestedSet.mark_subtree_dirty(nested_set, root.id)

      dirty_nodes = NestedSet.get_dirty_range(updated_nested_set)

      # Should have 3 dirty nodes
      assert length(dirty_nodes) == 3

      # Should be in offset order (parents before children)
      offsets = Enum.map(dirty_nodes, fn {offset, _node_id} -> offset end)
      assert offsets == [0, 1, 2]

      # Clean up
      Joint.cleanup(child2)
      Joint.cleanup(child1)
      Joint.cleanup(root)
    end
  end

  describe "NestedSet.is_node_dirty?/2" do
    test "returns false for clean node" do
      {:ok, root} = Joint.new()
      nested_set = NestedSet.build_nested_set([root])

      # Clear dirty flag
      clean_nested_set = %{nested_set | dirty_flags: %{0 => false}}

      assert NestedSet.is_node_dirty?(clean_nested_set, root.id) == false

      Joint.cleanup(root)
    end

    test "returns true for dirty node" do
      {:ok, root} = Joint.new()
      nested_set = NestedSet.build_nested_set([root])

      # Nodes start dirty by default
      assert NestedSet.is_node_dirty?(nested_set, root.id) == true

      Joint.cleanup(root)
    end

    test "returns false for non-existent node" do
      {:ok, root} = Joint.new()
      nested_set = NestedSet.build_nested_set([root])

      fake_id = make_ref()
      assert NestedSet.is_node_dirty?(nested_set, fake_id) == false

      Joint.cleanup(root)
    end
  end

  describe "HierarchyManager integration" do
    test "creates hierarchy manager" do
      {:ok, manager} = HierarchyManager.new()
      assert %HierarchyManager{} = manager
    end

    test "adds joints to hierarchy manager" do
      {:ok, manager} = HierarchyManager.new()
      {:ok, root} = Joint.new()

      updated_manager = HierarchyManager.add_joint(manager, root)

      # Should have root in root_nodes
      assert root.id in updated_manager.root_nodes

      # Should have incremented hierarchy version
      assert updated_manager.hierarchy_version == manager.hierarchy_version + 1

      Joint.cleanup(root)
    end

    test "removes joints from hierarchy manager" do
      {:ok, manager} = HierarchyManager.new()
      {:ok, root} = Joint.new()

      manager_with_joint = HierarchyManager.add_joint(manager, root)
      updated_manager = HierarchyManager.remove_joint(manager_with_joint, root.id)

      # Should no longer have root in root_nodes
      assert root.id not in updated_manager.root_nodes

      # Should have incremented hierarchy version again
      assert updated_manager.hierarchy_version == manager_with_joint.hierarchy_version + 1

      Joint.cleanup(root)
    end

    test "updates global transforms in batch" do
      {:ok, manager} = HierarchyManager.new()
      {:ok, root} = Joint.new()
      {:ok, child} = Joint.new(parent: root)

      # Add root to manager (child will be included via hierarchy)
      manager_with_hierarchy = HierarchyManager.add_joint(manager, root)

      # Update global transforms
      updated_manager = HierarchyManager.update_global_transforms(manager_with_hierarchy)

      # Should have cached transforms
      assert Map.has_key?(updated_manager.global_transforms, root.id)

      # Clean up
      Joint.cleanup(child)
      Joint.cleanup(root)
    end

    test "gets individual global transform with caching" do
      {:ok, manager} = HierarchyManager.new()
      {:ok, root} = Joint.new()

      # Set a specific transform
      transform = Matrix4.translation({1.0, 2.0, 3.0})
      updated_root = Joint.set_transform(root, transform)

      manager_with_joint = HierarchyManager.add_joint(manager, updated_root)

      # Get global transform
      global_transform =
        HierarchyManager.get_global_transform(manager_with_joint, updated_root.id)

      # Should be the same as the local transform (since it's root)
      assert Matrix4.equal?(global_transform, transform)

      Joint.cleanup(updated_root)
    end

    test "marks subtree dirty efficiently" do
      {:ok, manager} = HierarchyManager.new()
      {:ok, root} = Joint.new()
      {:ok, child} = Joint.new(parent: root)

      manager_with_hierarchy = HierarchyManager.add_joint(manager, root)

      # Mark subtree dirty
      updated_manager = HierarchyManager.mark_subtree_dirty(manager_with_hierarchy, root.id)

      # Root should be dirty
      assert NestedSet.is_node_dirty?(updated_manager.nested_set, root.id)

      # Clean up
      Joint.cleanup(child)
      Joint.cleanup(root)
    end

    test "provides performance statistics" do
      {:ok, manager} = HierarchyManager.new()
      {:ok, root} = Joint.new()
      {:ok, child} = Joint.new(parent: root)

      manager_with_hierarchy = HierarchyManager.add_joint(manager, root)

      stats = HierarchyManager.get_stats(manager_with_hierarchy)

      assert stats.total_nodes > 0
      assert stats.hierarchy_version > 0
      assert is_integer(stats.dirty_nodes)
      assert is_integer(stats.cached_transforms)

      # Clean up
      Joint.cleanup(child)
      Joint.cleanup(root)
    end
  end

  describe "nested set invariants" do
    test "maintains parent-before-children ordering" do
      {:ok, root} = Joint.new()
      {:ok, child1} = Joint.new(parent: root)
      {:ok, child2} = Joint.new(parent: child1)
      {:ok, child3} = Joint.new(parent: child2)

      nested_set = NestedSet.build_nested_set([root])

      # Get metadata for all nodes
      root_meta = Map.get(nested_set.node_id_to_metadata, root.id)
      child1_meta = Map.get(nested_set.node_id_to_metadata, child1.id)
      child2_meta = Map.get(nested_set.node_id_to_metadata, child2.id)
      child3_meta = Map.get(nested_set.node_id_to_metadata, child3.id)

      # Parent should come before children in offset order
      assert root_meta.offset < child1_meta.offset
      assert child1_meta.offset < child2_meta.offset
      assert child2_meta.offset < child3_meta.offset

      # Each parent should contain all descendants in its span
      assert root_meta.offset + root_meta.span > child3_meta.offset
      assert child1_meta.offset + child1_meta.span > child3_meta.offset
      assert child2_meta.offset + child2_meta.span > child3_meta.offset

      # Clean up
      Joint.cleanup(child3)
      Joint.cleanup(child2)
      Joint.cleanup(child1)
      Joint.cleanup(root)
    end

    test "span calculation includes all descendants" do
      {:ok, root} = Joint.new()
      {:ok, left} = Joint.new(parent: root)
      {:ok, right} = Joint.new(parent: root)
      {:ok, left_child} = Joint.new(parent: left)
      {:ok, right_child} = Joint.new(parent: right)

      nested_set = NestedSet.build_nested_set([root])

      # Root should span entire tree
      root_meta = Map.get(nested_set.node_id_to_metadata, root.id)
      # All 5 nodes
      assert root_meta.span == 5

      # Left subtree should span 2 nodes (left + left_child)
      left_meta = Map.get(nested_set.node_id_to_metadata, left.id)
      assert left_meta.span == 2

      # Right subtree should span 2 nodes (right + right_child)
      right_meta = Map.get(nested_set.node_id_to_metadata, right.id)
      assert right_meta.span == 2

      # Leaf nodes should span 1 (themselves)
      left_child_meta = Map.get(nested_set.node_id_to_metadata, left_child.id)
      right_child_meta = Map.get(nested_set.node_id_to_metadata, right_child.id)
      assert left_child_meta.span == 1
      assert right_child_meta.span == 1

      # Clean up
      Joint.cleanup(right_child)
      Joint.cleanup(left_child)
      Joint.cleanup(right)
      Joint.cleanup(left)
      Joint.cleanup(root)
    end
  end
end
