# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.IOTest do
  use ExUnit.Case, async: true

  alias AriaGltf.{IO, Document, Asset, Scene, Node, Mesh, Material}
  alias AriaGltfProcessing.{Fixtures, TestHelpers}

  describe "export_to_file/2" do
    test "exports basic glTF document to file" do
      document = %Document{
        asset: %Asset{version: "2.0", generator: "AriaGltf.Test"},
        meshes: [],
        materials: [],
        scenes: []
      }

      output_path = TestHelpers.temp_file_path("test_export.gltf")

      assert {:ok, ^output_path} = IO.export_to_file(document, output_path)
      assert File.exists?(output_path)

      # Verify file is valid JSON
      {:ok, content} = File.read(output_path)
      assert {:ok, _} = Jason.decode(content)

      TestHelpers.cleanup_temp_file(output_path)
    end

    test "exports document with meshes, materials, and scenes" do
      # Create a document with basic structure
      scene = %Scene{
        name: "TestScene",
        nodes: [0]
      }

      node = %Node{
        name: "TestNode",
        mesh: 0
      }

      mesh = %Mesh{
        name: "TestMesh",
        primitives: []
      }

      material = %Material{
        name: "TestMaterial",
        pbr_metallic_roughness: %Material.PbrMetallicRoughness{
          base_color_factor: [1.0, 0.0, 0.0, 1.0]
        }
      }

      document = %Document{
        asset: %Asset{version: "2.0", generator: "AriaGltf.Test"},
        scenes: [scene],
        scene: 0,
        nodes: [node],
        meshes: [mesh],
        materials: [material]
      }

      output_path = TestHelpers.temp_file_path("test_export_structure.gltf")

      assert {:ok, ^output_path} = IO.export_to_file(document, output_path)

      # Verify exported file contains expected structure
      {:ok, content} = File.read(output_path)
      {:ok, json} = Jason.decode(content)

      assert json["asset"]["version"] == "2.0"
      assert length(json["scenes"] || []) == 1
      assert length(json["nodes"] || []) == 1
      assert length(json["meshes"] || []) == 1
      assert length(json["materials"] || []) == 1

      TestHelpers.cleanup_temp_file(output_path)
    end

    test "creates directory for output path if it doesn't exist" do
      document = %Document{
        asset: %Asset{version: "2.0", generator: "AriaGltf.Test"},
        meshes: [],
        materials: [],
        scenes: []
      }

      temp_dir = System.tmp_dir()
      nested_dir = Path.join([temp_dir, "aria_gltf_test", "nested", "path"])
      output_path = Path.join(nested_dir, "test_export.gltf")

      # Ensure the directory doesn't exist
      File.rm_rf(nested_dir)

      assert {:ok, ^output_path} = IO.export_to_file(document, output_path)
      assert File.exists?(output_path)
      assert File.exists?(nested_dir)

      TestHelpers.cleanup_temp_file(output_path)
      File.rm_rf(Path.dirname(nested_dir))
    end

    test "verifies exported JSON is valid glTF 2.0" do
      document = %Document{
        asset: %Asset{version: "2.0", generator: "AriaGltf.Test"},
        meshes: [],
        materials: [],
        scenes: []
      }

      output_path = TestHelpers.temp_file_path("test_gltf_validation.gltf")

      assert {:ok, ^output_path} = IO.export_to_file(document, output_path)

      # Verify JSON structure
      {:ok, content} = File.read(output_path)
      {:ok, json} = Jason.decode(content)

      # Check required glTF 2.0 structure
      assert json["asset"]["version"] == "2.0"
      assert is_map(json["asset"])

      # Verify optional arrays exist if present
      if Map.has_key?(json, "scenes"), do: assert(is_list(json["scenes"]))
      if Map.has_key?(json, "nodes"), do: assert(is_list(json["nodes"]))
      if Map.has_key?(json, "meshes"), do: assert(is_list(json["meshes"]))
      if Map.has_key?(json, "materials"), do: assert(is_list(json["materials"]))

      TestHelpers.cleanup_temp_file(output_path)
    end

    test "verifies exported file structure matches input document" do
      scene = %Scene{
        name: "MyScene",
        nodes: [0]
      }

      node = %Node{
        name: "MyNode",
        translation: [1.0, 2.0, 3.0]
      }

      document = %Document{
        asset: %Asset{
          version: "2.0",
          generator: "AriaGltf.Test",
          copyright: "Test Copyright"
        },
        scenes: [scene],
        scene: 0,
        nodes: [node],
        meshes: [],
        materials: []
      }

      output_path = TestHelpers.temp_file_path("test_structure_match.gltf")

      assert {:ok, ^output_path} = IO.export_to_file(document, output_path)

      {:ok, content} = File.read(output_path)
      {:ok, json} = Jason.decode(content)

      # Verify asset matches
      assert json["asset"]["version"] == document.asset.version
      assert json["asset"]["generator"] == document.asset.generator
      assert json["asset"]["copyright"] == document.asset.copyright

      # Verify scene matches
      assert length(json["scenes"]) == 1
      exported_scene = Enum.at(json["scenes"], 0)
      assert exported_scene["name"] == scene.name
      assert exported_scene["nodes"] == scene.nodes

      # Verify node matches
      assert length(json["nodes"]) == 1
      exported_node = Enum.at(json["nodes"], 0)
      assert exported_node["name"] == node.name
      assert exported_node["translation"] == node.translation

      TestHelpers.cleanup_temp_file(output_path)
    end

    test "returns error for invalid document (missing asset)" do
      document = %Document{
        asset: nil,
        meshes: [],
        materials: [],
        scenes: []
      }

      output_path = TestHelpers.temp_file_path("test_invalid.gltf")

      assert {:error, :missing_asset} = IO.export_to_file(document, output_path)

      # File should not be created
      refute File.exists?(output_path)
    end

    test "returns error for unsupported version" do
      document = %Document{
        asset: %Asset{version: "1.0", generator: "AriaGltf.Test"},
        meshes: [],
        materials: [],
        scenes: []
      }

      output_path = TestHelpers.temp_file_path("test_unsupported_version.gltf")

      assert {:error, {:unsupported_version, "1.0"}} = IO.export_to_file(document, output_path)

      # File should not be created
      refute File.exists?(output_path)
    end

    test "returns error for invalid arguments" do
      assert {:error, :invalid_arguments} = IO.export_to_file("not_a_document", "path")
      assert {:error, :invalid_arguments} = IO.export_to_file(%{not: :a_document}, "path")
    end
  end

  describe "save_binary/2" do
    test "exports binary glTF (GLB) format" do
      document = %Document{
        asset: %Asset{version: "2.0", generator: "AriaGltf.Test"},
        meshes: [],
        materials: [],
        scenes: [],
        buffers: [%AriaGltf.Buffer{byte_length: 0, data: <<>>}]
      }

      output_path = TestHelpers.temp_file_path("test_export.glb")

      assert :ok = IO.save_binary(document, output_path)
      assert File.exists?(output_path)

      # Verify GLB file structure
      {:ok, content} = File.read(output_path)

      # Check GLB magic number (first 4 bytes should be "glTF")
      <<magic::little-32, _version::little-32, _length::little-32, _rest::binary>> = content
      assert magic == 0x46546C67 # "glTF" in little-endian

      TestHelpers.cleanup_temp_file(output_path)
    end

    test "creates valid GLB with binary data" do
      # Create document with buffer data
      buffer_data = <<0, 1, 2, 3, 4, 5, 6, 7>>
      buffer = %AriaGltf.Buffer{
        byte_length: byte_size(buffer_data),
        data: buffer_data
      }

      document = %Document{
        asset: %Asset{version: "2.0", generator: "AriaGltf.Test"},
        meshes: [],
        materials: [],
        scenes: [],
        buffers: [buffer]
      }

      output_path = TestHelpers.temp_file_path("test_export_with_data.glb")

      assert :ok = IO.save_binary(document, output_path)
      assert File.exists?(output_path)

      # Verify file is larger than just header (has binary data)
      {:ok, file_info} = File.stat(output_path)
      assert file_info.size > 12 # Header size

      TestHelpers.cleanup_temp_file(output_path)
    end

    test "returns error for invalid document when saving GLB" do
      document = %Document{
        asset: nil,
        meshes: [],
        materials: [],
        scenes: []
      }

      output_path = TestHelpers.temp_file_path("test_invalid_glb.glb")

      assert {:error, :missing_asset} = IO.save_binary(document, output_path)

      # File should not be created
      refute File.exists?(output_path)
    end
  end

  describe "round-trip validation" do
    test "can import and re-export glTF file" do
      # Load a fixture file
      case Fixtures.load_gltf_fixture("simple_cube.gltf") do
        {:ok, fixture_path} ->
          # Import the file
          {:ok, document} = AriaGltf.Import.from_file(fixture_path)

          # Export to a new file
          output_path = TestHelpers.temp_file_path("test_round_trip.gltf")
          assert {:ok, ^output_path} = IO.export_to_file(document, output_path)

          # Verify exported file is valid
          {:ok, content} = File.read(output_path)
          assert {:ok, json} = Jason.decode(content)
          assert json["asset"]["version"] == "2.0"

          TestHelpers.cleanup_temp_file(output_path)

        {:error, :not_found} ->
          # Skip test if fixture doesn't exist
          :ok
      end
    end
  end
end

