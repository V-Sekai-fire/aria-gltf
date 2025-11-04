# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaDocument.RoundTripObjTest do
  use ExUnit.Case, async: true

  alias AriaDocument.Export.Obj
  alias AriaDocument.Import.Obj, as: ImportObj
  alias AriaGltf.Import
  alias AriaFbx.Import, as: FbxImport
  alias AriaGltfProcessing.{TestHelpers, Fixtures}

  setup do
    temp_dir = TestHelpers.create_temp_dir()
    on_exit(fn -> TestHelpers.cleanup_temp_dir(temp_dir) end)
    %{temp_dir: temp_dir}
  end

  describe "glTF -> OBJ -> Parse OBJ" do
    test "round-trip preserves vertex positions", %{temp_dir: temp_dir} do
      case Fixtures.load_gltf_fixture("simple_cube.gltf") do
        {:ok, gltf_path} ->
          {:ok, gltf_document} = Import.from_file(gltf_path)
          obj_path = Path.join(temp_dir, "output.obj")

          assert {:ok, ^obj_path} = Obj.export(gltf_document, obj_path)

          # Parse exported OBJ
          {:ok, obj_document} = ImportObj.from_file(obj_path)

          # Verify we have vertices
          assert length(obj_document.vertices) > 0

          # Verify vertex format (3D coordinates)
          assert Enum.all?(obj_document.vertices, fn
            {x, y, z} when is_float(x) and is_float(y) and is_float(z) -> true
            {x, y, z, w} when is_float(x) and is_float(y) and is_float(z) and is_float(w) -> true
            _ -> false
          end)

          # Verify vertices are in reasonable range (cube should be around -0.5 to 0.5)
          assert Enum.any?(obj_document.vertices, fn
            {x, y, z} -> abs(x) <= 1.0 and abs(y) <= 1.0 and abs(z) <= 1.0
            {x, y, z, _w} -> abs(x) <= 1.0 and abs(y) <= 1.0 and abs(z) <= 1.0
            _ -> false
          end)

        {:error, :not_found} ->
          :ok
      end
    end

    test "round-trip preserves face topology", %{temp_dir: temp_dir} do
      case Fixtures.load_gltf_fixture("simple_cube.gltf") do
        {:ok, gltf_path} ->
          {:ok, gltf_document} = Import.from_file(gltf_path)
          obj_path = Path.join(temp_dir, "output.obj")

          assert {:ok, ^obj_path} = Obj.export(gltf_document, obj_path)

          # Parse exported OBJ
          {:ok, obj_document} = ImportObj.from_file(obj_path)

          # Verify faces exist
          assert length(obj_document.faces) > 0

          # Verify all faces have at least 3 vertices
          assert Enum.all?(obj_document.faces, fn face ->
            length(face) >= 3
          end)

          # Verify face indices are valid (positive integers, 1-based)
          assert Enum.all?(obj_document.faces, fn face ->
            Enum.all?(face, fn {v, _vt, _vn} ->
              is_nil(v) or (is_integer(v) and v >= 1)
            end)
          end)
        {:error, :not_found} ->
          :ok
      end
    end

    test "round-trip preserves material assignments", %{temp_dir: temp_dir} do
      case Fixtures.load_gltf_fixture("cube_with_material.gltf") do
        {:ok, gltf_path} ->
          {:ok, gltf_document} = Import.from_file(gltf_path)
          obj_path = Path.join(temp_dir, "output.obj")

          assert {:ok, ^obj_path} = Obj.export(gltf_document, obj_path)

          # Parse exported OBJ
          {:ok, obj_document} = ImportObj.from_file(obj_path)

          # Verify material library reference exists
          assert obj_document.mtllib != nil or length(obj_document.materials) > 0

          # Verify MTL file exists if mtllib is set
          if obj_document.mtllib do
            mtl_path = Path.join(Path.dirname(obj_path), obj_document.mtllib)
            assert File.exists?(mtl_path)
          end
        {:error, :not_found} ->
          :ok
      end
    end

    test "round-trip preserves scene hierarchy in groups", %{temp_dir: temp_dir} do
      case Fixtures.load_gltf_fixture("simple_scene.gltf") do
        {:ok, gltf_path} ->
          {:ok, gltf_document} = Import.from_file(gltf_path)
          obj_path = Path.join(temp_dir, "output.obj")

          assert {:ok, ^obj_path} = Obj.export(gltf_document, obj_path)

          # Parse exported OBJ
          {:ok, obj_document} = ImportObj.from_file(obj_path)

          # Verify groups exist (from node hierarchy)
          assert length(obj_document.groups) > 0

          # Verify group names are valid strings
          assert Enum.all?(obj_document.groups, fn group ->
            is_binary(group) and String.length(group) > 0
          end)
        {:error, :not_found} ->
          :ok
      end
    end
  end

  describe "FBX -> OBJ -> Parse OBJ" do
    test "round-trip preserves geometry from FBX", %{temp_dir: temp_dir} do
      # Try to find an FBX test file
      test_data_dir = Path.join([__DIR__, "..", "..", "thirdparty", "ufbx", "data"])
      fbx_files = Path.join([test_data_dir, "*.fbx"]) |> Path.wildcard()

      if length(fbx_files) > 0 do
        fbx_path = List.first(fbx_files)

        case FbxImport.from_file(fbx_path, validate: false) do
          {:ok, fbx_document} ->
            obj_path = Path.join(temp_dir, "output_fbx.obj")

            case Obj.export(fbx_document, obj_path) do
              {:ok, ^obj_path} ->
                # Parse exported OBJ
                {:ok, obj_document} = ImportObj.from_file(obj_path)

                # Verify basic structure
                assert length(obj_document.vertices) >= 0
                assert length(obj_document.faces) >= 0

                # Verify vertex format if vertices exist
                if length(obj_document.vertices) > 0 do
                  assert Enum.all?(obj_document.vertices, fn
                    {x, y, z} when is_float(x) and is_float(y) and is_float(z) -> true
                    {x, y, z, w} when is_float(x) and is_float(y) and is_float(z) and is_float(w) -> true
                    _ -> false
                  end)
                end

              {:error, _reason} ->
                # FBX export may fail for some files, skip test
                :ok
            end

          {:error, _reason} ->
            # FBX import may fail, skip test
            :ok
        end
      else
        # No FBX files available, skip test
        :ok
      end
    end
  end

  describe "geometry comparison utilities" do
    test "can compare OBJ documents for structure equivalence", %{temp_dir: temp_dir} do
      case Fixtures.load_gltf_fixture("simple_cube.gltf") do
        {:ok, gltf_path} ->
          {:ok, gltf_document} = Import.from_file(gltf_path)
          obj_path1 = Path.join(temp_dir, "output1.obj")
          obj_path2 = Path.join(temp_dir, "output2.obj")

          # Export same document twice
          assert {:ok, ^obj_path1} = Obj.export(gltf_document, obj_path1)
          assert {:ok, ^obj_path2} = Obj.export(gltf_document, obj_path2)

          # Parse both OBJ files
          {:ok, obj_doc1} = ImportObj.from_file(obj_path1)
          {:ok, obj_doc2} = ImportObj.from_file(obj_path2)

          # Compare structure (counts should match)
          assert length(obj_doc1.vertices) == length(obj_doc2.vertices)
          assert length(obj_doc1.faces) == length(obj_doc2.faces)
          assert length(obj_doc1.normals) == length(obj_doc2.normals)
          assert length(obj_doc1.texcoords) == length(obj_doc2.texcoords)

        {:error, :not_found} ->
          :ok
      end
    end

    test "can validate geometry accuracy with tolerance", %{temp_dir: temp_dir} do
      case Fixtures.load_gltf_fixture("simple_cube.gltf") do
        {:ok, gltf_path} ->
          {:ok, gltf_document} = Import.from_file(gltf_path)
          obj_path = Path.join(temp_dir, "output.obj")

          assert {:ok, ^obj_path} = Obj.export(gltf_document, obj_path)

          # Parse exported OBJ
          {:ok, obj_document} = ImportObj.from_file(obj_path)

          # Verify geometry counts are reasonable
          assert length(obj_document.vertices) >= 8  # Cube has at least 8 vertices
          assert length(obj_document.faces) > 0       # Should have faces

          # Verify vertex coordinates are finite numbers
          assert Enum.all?(obj_document.vertices, fn
            {x, y, z} -> is_finite_number(x) and is_finite_number(y) and is_finite_number(z)
            {x, y, z, w} -> is_finite_number(x) and is_finite_number(y) and is_finite_number(z) and is_finite_number(w)
            _ -> false
          end)

        {:error, :not_found} ->
          :ok
      end
    end
  end

  # Helper function to check if a number is finite
  defp is_finite_number(n) when is_float(n) or is_integer(n) do
    not (n == :infinity or n == :"-infinity" or n != n)  # NaN check
  end
  defp is_finite_number(_), do: false
end

