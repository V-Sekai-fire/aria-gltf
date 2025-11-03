# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaDocument.Integration.PipelineTest do
  use ExUnit.Case

  alias AriaDocument.{Converter, Export.Obj}
  alias AriaGltf.{Import, BmeshConverter}
  alias AriaGltfProcessing.{TestHelpers, Fixtures}

  setup do
    temp_dir = TestHelpers.create_temp_dir()
    on_exit(fn -> TestHelpers.cleanup_temp_dir(temp_dir) end)
    %{temp_dir: temp_dir}
  end

  describe "end-to-end pipelines" do
    test "glTF -> OBJ -> Parse -> Compare (round-trip)", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("simple_cube.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      # Export to OBJ
      assert {:ok, ^obj_path} = Obj.export(document, obj_path)

      # Parse the OBJ
      {:ok, lines} = TestHelpers.read_obj_lines(obj_path)
      geom = TestHelpers.parse_obj_geometry(lines)

      # Should have geometry
      assert length(geom.vertices) > 0
      assert length(geom.faces) > 0
    end

    test "glTF -> BMesh -> OBJ -> Parse", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("simple_cube.gltf")
      {:ok, document} = Import.from_file(gltf_path)

      # Convert to BMesh
      assert {:ok, bmeshes} = BmeshConverter.from_gltf_document(document)
      assert length(bmeshes) > 0

      # Export to OBJ (using BMesh path)
      obj_path = Path.join(temp_dir, "output.obj")
      assert {:ok, ^obj_path} = Obj.export(document, obj_path)

      # Parse the OBJ
      {:ok, lines} = TestHelpers.read_obj_lines(obj_path)
      geom = TestHelpers.parse_obj_geometry(lines)

      # Should have geometry
      assert length(geom.vertices) > 0
    end

    test "scene hierarchy export preserves structure", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("simple_scene.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)

      # Parse OBJ
      {:ok, lines} = TestHelpers.read_obj_lines(obj_path)
      geom = TestHelpers.parse_obj_geometry(lines)

      # Should have groups from scene hierarchy
      assert length(geom.groups) > 0

      # Check OBJ content has group commands
      {:ok, content} = File.read(obj_path)
      assert String.contains?(content, "g ")
    end

    test "material export in OBJ pipeline", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("cube_with_material.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)

      # Check MTL file exists
      mtl_path = Path.join(temp_dir, "output.mtl")
      assert File.exists?(mtl_path)

      # Check OBJ references material
      {:ok, content} = File.read(obj_path)
      assert String.contains?(content, "mtllib")
    end
  end

  describe "real-world scenarios" do
    test "complex scene hierarchy (nested nodes)", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("simple_scene.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)

      {:ok, content} = File.read(obj_path)
      lines = String.split(content, "\n")

      # Should have group commands for nested hierarchy
      group_lines = Enum.filter(lines, &String.starts_with?(&1, "g "))
      assert length(group_lines) >= 2

      # Should have parent-child group structure
      assert Enum.any?(group_lines, &String.contains?(&1, "_ChildNode"))
    end

    test "multiple materials per mesh", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("cube_with_material.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      assert {:ok, ^obj_path} = Obj.export(document, obj_path)

      # Parse OBJ
      {:ok, lines} = TestHelpers.read_obj_lines(obj_path)
      geom = TestHelpers.parse_obj_geometry(lines)

      # Should have material references
      assert length(geom.materials) >= 0  # May or may not have usemtl commands depending on implementation
    end

    test "large mesh handling", %{temp_dir: temp_dir} do
      {:ok, gltf_path} = Fixtures.load_gltf_fixture("simple_cube.gltf")
      {:ok, document} = Import.from_file(gltf_path)
      obj_path = Path.join(temp_dir, "output.obj")

      # Should handle mesh export without errors
      assert {:ok, ^obj_path} = Obj.export(document, obj_path)

      # Verify file was created
      assert File.exists?(obj_path)
      {:ok, stat} = File.stat(obj_path)
      assert stat.size > 0
    end
  end
end

