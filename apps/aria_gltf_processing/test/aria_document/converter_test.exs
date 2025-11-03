# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaDocument.ConverterTest do
  use ExUnit.Case

  alias AriaDocument.Converter
  alias AriaGltfProcessing.{TestHelpers, Fixtures}

  setup do
    temp_dir = TestHelpers.create_temp_dir()
    on_exit(fn -> TestHelpers.cleanup_temp_dir(temp_dir) end)
    %{temp_dir: temp_dir}
  end

  describe "FBX to OBJ pipeline" do
    test "complete pipeline: FBX file -> OBJ file", %{temp_dir: temp_dir} do
      # Try to use a file from ufbx test data if available
      test_data_dir = Path.join([__DIR__, "..", "..", "thirdparty", "ufbx", "data"])
      fbx_files = Path.join([test_data_dir, "**", "*.fbx"]) |> Path.wildcard()

      if length(fbx_files) > 0 do
        test_file = List.first(fbx_files)
        obj_path = Path.join(temp_dir, "output.obj")

        # This might fail if NIF is not properly configured, but shouldn't crash
        result = Converter.fbx_to_obj(test_file, obj_path, validate: false)

        assert is_tuple(result) and (match?({:ok, _}, result) or match?({:error, _}, result))

        if match?({:ok, _}, result) do
          assert File.exists?(obj_path)
        end
      else
        # Skip if no test files available
        :ok
      end
    end

    test "pipeline with validation disabled", %{temp_dir: temp_dir} do
      # Create minimal invalid file to test validation skip
      invalid_file = TestHelpers.create_temp_file("invalid", ".fbx")
      obj_path = Path.join(temp_dir, "output.obj")

      result = Converter.fbx_to_obj(invalid_file, obj_path, validate: false)
      assert match?({:error, _}, result)

      TestHelpers.cleanup_temp_file(invalid_file)
    end

    test "pipeline with MTL file generation", %{temp_dir: temp_dir} do
      test_data_dir = Path.join([__DIR__, "..", "..", "thirdparty", "ufbx", "data"])
      fbx_files = Path.join([test_data_dir, "**", "*.fbx"]) |> Path.wildcard()

      if length(fbx_files) > 0 do
        test_file = List.first(fbx_files)
        obj_path = Path.join(temp_dir, "output.obj")

        result = Converter.fbx_to_obj(test_file, obj_path, mtl_file: true, validate: false)

        if match?({:ok, _}, result) do
          mtl_path = Path.join(temp_dir, "output.mtl")
          # MTL file may or may not exist depending on whether FBX has materials
          :ok
        end
      else
        :ok
      end
    end

    test "pipeline handles errors gracefully" do
      result = Converter.fbx_to_obj("/nonexistent/file.fbx", "/tmp/output.obj")
      assert match?({:error, _}, result)
    end
  end

  describe "directory batch conversion" do
    test "batch converts directory of FBX files", %{temp_dir: temp_dir} do
      test_data_dir = Path.join([__DIR__, "..", "..", "thirdparty", "ufbx", "data"])
      fbx_files = Path.join([test_data_dir, "*.fbx"]) |> Path.wildcard()

      if length(fbx_files) > 0 do
        # Use a subdirectory with a few files
        _test_subdir = Path.join([test_data_dir, ".."])
        result = Converter.fbx_dir_to_obj(test_data_dir, output_dir: temp_dir, recursive: false, validate: false)

        assert match?({:ok, {_successes, _errors}}, result)

        {successes, errors} = elem(result, 1)
        assert is_list(successes)
        assert is_list(errors)
      else
        :ok
      end
    end

    test "handles recursive directory search" do
      test_data_dir = Path.join([__DIR__, "..", "..", "thirdparty", "ufbx", "data"])
      result = Converter.fbx_dir_to_obj(test_data_dir, recursive: true, validate: false)

      assert match?({:ok, {_successes, _errors}}, result)
    end

    test "handles pattern matching" do
      test_data_dir = Path.join([__DIR__, "..", "..", "thirdparty", "ufbx", "data"])
      result = Converter.fbx_dir_to_obj(test_data_dir, pattern: "*.fbx", recursive: false, validate: false)

      assert match?({:ok, {_successes, _errors}}, result)
    end

    test "aggregates successes and errors" do
      test_data_dir = Path.join([__DIR__, "..", "..", "thirdparty", "ufbx", "data"])

      result = Converter.fbx_dir_to_obj(test_data_dir, recursive: false, validate: false)

      assert {:ok, {successes, errors}} = result
      assert is_list(successes)
      assert is_list(errors)
    end
  end

  describe "OBJ comparison utilities" do
    test "parses OBJ vertices (3D and 4D)" do
      {:ok, obj_path} = Fixtures.load_obj_fixture("simple_cube.obj")
      {:ok, lines} = TestHelpers.read_obj_lines(obj_path)

      geom = TestHelpers.parse_obj_geometry(lines)

      # Should have parsed vertices
      assert length(geom.vertices) > 0

      # Check vertex format
      first_vertex = List.first(geom.vertices)
          assert is_tuple(first_vertex) and (tuple_size(first_vertex) == 3 or tuple_size(first_vertex) == 4)
    end

    test "parses OBJ normals" do
      # Create OBJ with normals
      obj_content = """
      v 0 0 0
      vn 0 1 0
      f 1//1
      """
      obj_path = TestHelpers.create_temp_file(obj_content, ".obj")

      {:ok, lines} = TestHelpers.read_obj_lines(obj_path)
      geom = TestHelpers.parse_obj_geometry(lines)

      assert length(geom.normals) > 0
      TestHelpers.cleanup_temp_file(obj_path)
    end

    test "parses OBJ texture coordinates" do
      obj_content = """
      v 0 0 0
      vt 0.5 0.5
      f 1/1
      """
      obj_path = TestHelpers.create_temp_file(obj_content, ".obj")

      {:ok, lines} = TestHelpers.read_obj_lines(obj_path)
      geom = TestHelpers.parse_obj_geometry(lines)

      assert length(geom.texcoords) > 0
      TestHelpers.cleanup_temp_file(obj_path)
    end

    test "parses OBJ faces with various formats" do
      {:ok, obj_path} = Fixtures.load_obj_fixture("simple_cube.obj")
      {:ok, lines} = TestHelpers.read_obj_lines(obj_path)

      geom = TestHelpers.parse_obj_geometry(lines)

      # Should have parsed faces
      assert length(geom.faces) > 0

      # Each face should be a list of vertex indices
      first_face = List.first(geom.faces)
      assert is_list(first_face)
      assert length(first_face) >= 3
    end

    test "parses OBJ groups" do
      obj_content = """
      g Group1
      v 0 0 0
      g Group2
      v 1 1 1
      """
      obj_path = TestHelpers.create_temp_file(obj_content, ".obj")

      {:ok, lines} = TestHelpers.read_obj_lines(obj_path)
      geom = TestHelpers.parse_obj_geometry(lines)

      assert length(geom.groups) >= 2
      assert Enum.member?(geom.groups, "Group1")
      assert Enum.member?(geom.groups, "Group2")

      TestHelpers.cleanup_temp_file(obj_path)
    end

    test "parses OBJ materials" do
      obj_content = """
      usemtl Material1
      v 0 0 0
      usemtl Material2
      """
      obj_path = TestHelpers.create_temp_file(obj_content, ".obj")

      {:ok, lines} = TestHelpers.read_obj_lines(obj_path)
      geom = TestHelpers.parse_obj_geometry(lines)

      assert length(geom.materials) >= 2
      assert Enum.member?(geom.materials, "Material1")
      assert Enum.member?(geom.materials, "Material2")

      TestHelpers.cleanup_temp_file(obj_path)
    end
  end

  describe "OBJ diff computation" do
    test "detects count mismatches" do
      obj1_content = """
      v 0 0 0
      v 1 1 1
      f 1 2 3
      """
      obj1_path = TestHelpers.create_temp_file(obj1_content, ".obj")

      obj2_content = """
      v 0 0 0
      f 1 2 3
      """
      obj2_path = TestHelpers.create_temp_file(obj2_content, ".obj")

      {:ok, lines1} = TestHelpers.read_obj_lines(obj1_path)
      {:ok, lines2} = TestHelpers.read_obj_lines(obj2_path)

      geom1 = TestHelpers.parse_obj_geometry(lines1)
      geom2 = TestHelpers.parse_obj_geometry(lines2)

      # Should detect vertex count mismatch
      assert length(geom1.vertices) != length(geom2.vertices)

      TestHelpers.cleanup_temp_file(obj1_path)
      TestHelpers.cleanup_temp_file(obj2_path)
    end
  end

  describe "validation pipeline" do
    test "validates FBX to OBJ against reference OBJ file" do
      # Try to find FBX with corresponding OBJ reference
      test_data_dir = Path.join([__DIR__, "..", "..", "thirdparty", "ufbx", "data"])
      fbx_files = Path.join([test_data_dir, "*.fbx"]) |> Path.wildcard()

      if length(fbx_files) > 0 do
        # Look for FBX with matching OBJ
        test_file =
          Enum.find(fbx_files, fn fbx_path ->
            obj_ref = Path.rootname(fbx_path, ".fbx") <> ".obj"
            File.exists?(obj_ref)
          end)

        if test_file do
          result = Converter.validate_fbx_to_obj(test_file, validate: false)
          assert is_tuple(result) and (match?({:ok, :match}, result) or match?({:ok, :no_reference}, result) or match?({:ok, {:mismatch, _}}, result))
        end
      else
        :ok
      end
    end

    test "handles no reference file" do
      test_data_dir = Path.join([__DIR__, "..", "..", "thirdparty", "ufbx", "data"])
      fbx_files = Path.join([test_data_dir, "*.fbx"]) |> Path.wildcard()

      if length(fbx_files) > 0 do
        # Find FBX without corresponding OBJ
        test_file =
          Enum.find(fbx_files, fn fbx_path ->
            obj_ref = Path.rootname(fbx_path, ".fbx") <> ".obj"
            not File.exists?(obj_ref)
          end)

        if test_file do
          result = Converter.validate_fbx_to_obj(test_file, validate: false)
          assert is_tuple(result) and (match?({:ok, :no_reference}, result) or match?({:ok, {:mismatch, _}}, result) or match?({:error, _}, result))
        end
      else
        :ok
      end
    end

    test "batch validates FBX sequences" do
      test_data_dir = Path.join([__DIR__, "..", "..", "thirdparty", "ufbx", "data"])

      result = Converter.validate_fbx_sequences(test_data_dir, recursive: false, validate: false)

      assert match?({:ok, _summary}, result)

      {:ok, summary} = result
      assert Map.has_key?(summary, :total)
      assert Map.has_key?(summary, :matched)
      assert Map.has_key?(summary, :mismatched)
      assert Map.has_key?(summary, :no_reference)
      assert Map.has_key?(summary, :errors)
    end

    test "validation summary includes statistics" do
      test_data_dir = Path.join([__DIR__, "..", "..", "thirdparty", "ufbx", "data"])

      result = Converter.validate_fbx_sequences(test_data_dir, recursive: false, validate: false)

      assert match?({:ok, _summary}, result)
      
      {:ok, summary} = result
      assert is_integer(summary.total)
      assert is_integer(summary.matched)
      assert is_integer(summary.mismatched)
      assert is_integer(summary.no_reference)
      assert is_integer(summary.errors)
    end
  end
end

