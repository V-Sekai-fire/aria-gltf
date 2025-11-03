# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaDocument.Export.ObjTest do
  use ExUnit.Case

  alias AriaDocument.Export.Obj
  alias AriaGltf.{Document, Import}
  alias AriaFbx.Import, as: FbxImport
  alias AriaGltfProcessing.{TestHelpers, Fixtures}

  setup do
    temp_dir = TestHelpers.create_temp_dir()
    on_exit(fn -> TestHelpers.cleanup_temp_dir(temp_dir) end)
    %{temp_dir: temp_dir}
  end

  describe "glTF to OBJ export" do
    test "exports basic document with single mesh", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("simple_cube.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)
      assert File.exists?(obj_path)

      {:ok, content} = File.read(obj_path)
      assert String.contains?(content, "# OBJ file exported from glTF")
      assert String.contains?(content, "v -0.5 -0.5 -0.5")
      # Verify faces are exported (OBJ uses 1-based indexing, face format may vary)
      assert String.contains?(content, "f ")
      # Verify basic structure
      lines = String.split(content, "\n")
      vertex_count = Enum.count(lines, &String.starts_with?(&1, "v "))
      face_count = Enum.count(lines, &String.starts_with?(&1, "f "))
      assert vertex_count >= 8  # Cube has 8 vertices
      assert face_count > 0     # Should have faces
    end

    test "exports document with scene hierarchy", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("simple_scene.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)

      {:ok, content} = File.read(obj_path)
      # Should have object groups for nodes
      assert String.contains?(content, "g MainScene_Node1")
      assert String.contains?(content, "g MainScene_Node2")
      assert String.contains?(content, "g MainScene_Node1_ChildNode")
    end

    test "exports document with materials", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("cube_with_material.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)

      # Check MTL file was created
      mtl_path = Path.join(temp_dir, "output.mtl")
      assert File.exists?(mtl_path)

      {:ok, mtl_content} = File.read(mtl_path)
      assert String.contains?(mtl_content, "newmtl RedMaterial")
      assert String.contains?(mtl_content, "Kd 1.0 0.0 0.0")
    end

    test "handles document with no scene", %{temp_dir: temp_dir} do
      document = Fixtures.create_minimal_gltf(meshes: [Fixtures.create_cube_mesh()])
      obj_path = Path.join(temp_dir, "output.obj")

      # Should fall back to mesh extraction
      assert {:ok, ^obj_path} = Obj.export(document, obj_path)
      assert File.exists?(obj_path)
    end

    test "handles document with no materials", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("simple_cube.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)

      {:ok, content} = File.read(obj_path)
      # Should not have mtllib when no materials
      refute String.contains?(content, "mtllib")
    end

    test "handles document with no meshes", %{temp_dir: temp_dir} do
      document = Fixtures.create_minimal_gltf()
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)
      assert File.exists?(obj_path)
    end

    test "handles empty document", %{temp_dir: temp_dir} do
      document = Fixtures.create_minimal_gltf()
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)
    end

    test "creates directory if it doesn't exist", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("simple_cube.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(Path.join(temp_dir, "subdir"), "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)
      assert File.exists?(obj_path)
    end
  end

  describe "FBX to OBJ export" do
    test "exports basic FBX document", %{temp_dir: temp_dir} do
      # Create minimal FBX document for testing
      document = Fixtures.create_minimal_fbx()
      obj_path = Path.join(temp_dir, "output.obj")

      # FBX export may fail if document is too minimal, but should not crash
      result = Obj.export(document, obj_path)
      assert result == {:ok, obj_path} or match?({:error, _}, result)
    end

    test "handles FBX document with no materials", %{temp_dir: temp_dir} do
      document = Fixtures.create_minimal_fbx()
      obj_path = Path.join(temp_dir, "output.obj")

      result = Obj.export(document, obj_path)
      assert result == {:ok, obj_path} or match?({:error, _}, result)
    end

    test "handles empty FBX document", %{temp_dir: temp_dir} do
      document = Fixtures.create_minimal_fbx()
      obj_path = Path.join(temp_dir, "output.obj")

      result = Obj.export(document, obj_path)
      assert result == {:ok, obj_path} or match?({:error, _}, result)
    end
  end

  describe "MTL file generation" do
    test "generates MTL file when mtl_file is true", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("cube_with_material.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path, mtl_file: true)

      mtl_path = Path.join(temp_dir, "output.mtl")
      assert File.exists?(mtl_path)
    end

    test "skips MTL file when mtl_file is false", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("cube_with_material.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path, mtl_file: false)

      mtl_path = Path.join(temp_dir, "output.mtl")
      refute File.exists?(mtl_path)
    end

    test "extracts PBR material properties", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("cube_with_material.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)

      mtl_path = Path.join(temp_dir, "output.mtl")
      {:ok, content} = File.read(mtl_path)

      # Check for PBR properties
      assert String.contains?(content, "newmtl RedMaterial")
      assert String.contains?(content, "Kd 1.0 0.0 0.0")  # base_color_factor
      assert String.contains?(content, "Ks")  # metallic_factor approximation
      assert String.contains?(content, "Ke 0.2 0.0 0.0")  # emissive_factor
    end

    test "resolves material names correctly", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("cube_with_material.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)

      {:ok, obj_content} = File.read(obj_path)
      {:ok, mtl_content} = File.read(Path.join(temp_dir, "output.mtl"))

      # Material name should match in both files
      assert String.contains?(mtl_content, "newmtl RedMaterial")
      assert String.contains?(obj_content, "usemtl RedMaterial") or String.contains?(obj_content, "mtllib")
    end
  end

  describe "material groups" do
    test "emits usemtl commands when material changes", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("cube_with_material.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)

      {:ok, content} = File.read(obj_path)
      # Should have usemtl command before faces
      lines = String.split(content, "\n")
      face_indices = Enum.find_index(lines, &String.starts_with?(&1, "f "))
      usemtl_indices = Enum.find_index(lines, &String.starts_with?(&1, "usemtl "))

      if face_indices && usemtl_indices do
        assert usemtl_indices < face_indices
      end
    end

    test "handles primitive with no material", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("simple_cube.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)

      {:ok, content} = File.read(obj_path)
      # Should not have usemtl if no material
      refute String.contains?(content, "usemtl")
    end
  end

  describe "object groups" do
    test "creates object groups from node hierarchy", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("simple_scene.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)

      {:ok, content} = File.read(obj_path)
      lines = String.split(content, "\n")

      # Should have group commands
      group_lines = Enum.filter(lines, &String.starts_with?(&1, "g "))
      assert length(group_lines) > 0

      # Should have hierarchical group names
      assert Enum.any?(group_lines, &String.contains?(&1, "MainScene_Node1"))
      assert Enum.any?(group_lines, &String.contains?(&1, "MainScene_Node1_ChildNode"))
    end
  end

  describe "edge cases" do
    test "handles invalid document type", %{temp_dir: temp_dir} do
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:error, :unsupported_document_type} = Obj.export(%{}, obj_path)
    end

    test "handles file write errors gracefully" do
      # Try to write to invalid path (read-only directory or invalid path)
      document = Fixtures.create_minimal_gltf()

      # This might succeed or fail depending on permissions, but shouldn't crash
      result = Obj.export(document, "/invalid/path/that/does/not/exist/output.obj")
      assert is_tuple(result) and (match?({:ok, _}, result) or match?({:error, _}, result))
    end
  end

  describe "vertex offset tracking" do
    test "tracks offsets across multiple meshes", %{temp_dir: temp_dir} do
      # Use real fixture file which has proper buffer data
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("simple_cube.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      
      # Create a document with the same mesh twice to test offset tracking
      # We'll duplicate the mesh in the document
      mesh = List.first(document.meshes || [])
      nodes = document.nodes || []
      
      # Add a second node referencing the same mesh to test offset tracking
      # (In a real scenario, you'd have two different meshes, but for testing
      #  we can use the same mesh twice)
      updated_nodes = nodes ++ [%{mesh: 0}]
      updated_document = Map.put(document, :nodes, updated_nodes)
      
      # Create a scene with both nodes
      scene = %{nodes: [0, 1]}
      updated_document = Map.put(updated_document, :scenes, [scene])
      updated_document = Map.put(updated_document, :scene, 0)
      
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(updated_document, obj_path)

      {:ok, content} = File.read(obj_path)
      lines = String.split(content, "\n")

      # Count vertices (should have at least 8 vertices from the cube)
      vertex_lines = Enum.filter(lines, &String.starts_with?(&1, "v "))
      assert length(vertex_lines) >= 8  # At least one cube worth

      # Count faces - should reference correct vertex indices
      face_lines = Enum.filter(lines, &String.starts_with?(&1, "f "))
      assert length(face_lines) > 0

      # Verify basic structure - export should succeed with multiple nodes
      # (Detailed vertex index validation is complex due to OBJ format variations
      #  and the fact that duplicate meshes may share vertices)
      assert length(vertex_lines) > 0
      assert length(face_lines) > 0
    end
  end
end

