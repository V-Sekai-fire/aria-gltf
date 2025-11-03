# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Import.Parser.Material do
  @moduledoc """
  Material-related parsing for glTF content.

  This module handles parsing of materials, textures, images, and samplers from glTF JSON data.
  """

  alias AriaGltf.{Material, Texture, TextureInfo, Image, Sampler}
  alias AriaGltf.Import.Parser.Utility

  @doc """
  Parses materials array from glTF JSON data.

  ## Examples

      iex> materials_data = [%{"name" => "Material", "pbrMetallicRoughness" => %{"baseColorFactor" => [1, 0, 0, 1]}}]
      iex> AriaGltf.Import.Parser.Material.parse_materials(materials_data)
      [%AriaGltf.Material{name: "Material", pbr_metallic_roughness: %AriaGltf.Material.PbrMetallicRoughness{base_color_factor: [1, 0, 0, 1]}}]
  """
  @spec parse_materials(list() | nil) :: [Material.t()]
  def parse_materials(nil), do: []

  def parse_materials(materials_data) when is_list(materials_data) do
    Enum.map(materials_data, &parse_material/1)
  end

  @spec parse_material(map()) :: Material.t()
  defp parse_material(material_data) when is_map(material_data) do
    %Material{
      name: material_data["name"],
      pbr_metallic_roughness: parse_pbr_metallic_roughness(material_data["pbrMetallicRoughness"]),
      normal_texture: parse_normal_texture_info(material_data["normalTexture"]),
      occlusion_texture: parse_occlusion_texture_info(material_data["occlusionTexture"]),
      emissive_texture: parse_texture_info(material_data["emissiveTexture"]),
      emissive_factor: Utility.parse_vec3(material_data["emissiveFactor"]) || [0.0, 0.0, 0.0],
      alpha_mode: material_data["alphaMode"] || "OPAQUE",
      alpha_cutoff: material_data["alphaCutoff"] || 0.5,
      double_sided: material_data["doubleSided"] || false,
      extensions: material_data["extensions"],
      extras: material_data["extras"]
    }
  end

  @spec parse_pbr_metallic_roughness(map() | nil) :: Material.PbrMetallicRoughness.t() | nil
  defp parse_pbr_metallic_roughness(nil), do: nil

  defp parse_pbr_metallic_roughness(pbr_data) when is_map(pbr_data) do
    %Material.PbrMetallicRoughness{
      base_color_factor: Utility.parse_vec4(pbr_data["baseColorFactor"]) || [1.0, 1.0, 1.0, 1.0],
      base_color_texture: parse_texture_info(pbr_data["baseColorTexture"]),
      metallic_factor: pbr_data["metallicFactor"] || 1.0,
      roughness_factor: pbr_data["roughnessFactor"] || 1.0,
      metallic_roughness_texture: parse_texture_info(pbr_data["metallicRoughnessTexture"]),
      extensions: pbr_data["extensions"],
      extras: pbr_data["extras"]
    }
  end

  @doc """
  Parses texture info from glTF JSON data.

  ## Examples

      iex> texture_info = %{"index" => 0, "texCoord" => 1}
      iex> AriaGltf.Import.Parser.Material.parse_texture_info(texture_info)
      %AriaGltf.TextureInfo{index: 0, tex_coord: 1}
  """
  @spec parse_texture_info(map() | nil) :: TextureInfo.t() | nil
  def parse_texture_info(nil), do: nil

  def parse_texture_info(texture_info) when is_map(texture_info) do
    %TextureInfo{
      index: texture_info["index"],
      tex_coord: texture_info["texCoord"] || 0,
      extensions: texture_info["extensions"],
      extras: texture_info["extras"]
    }
  end

  @spec parse_normal_texture_info(map() | nil) :: Material.NormalTextureInfo.t() | nil
  defp parse_normal_texture_info(nil), do: nil

  defp parse_normal_texture_info(texture_info) when is_map(texture_info) do
    %Material.NormalTextureInfo{
      index: texture_info["index"],
      tex_coord: texture_info["texCoord"] || 0,
      scale: texture_info["scale"] || 1.0,
      extensions: texture_info["extensions"],
      extras: texture_info["extras"]
    }
  end

  @spec parse_occlusion_texture_info(map() | nil) :: Material.OcclusionTextureInfo.t() | nil
  defp parse_occlusion_texture_info(nil), do: nil

  defp parse_occlusion_texture_info(texture_info) when is_map(texture_info) do
    %Material.OcclusionTextureInfo{
      index: texture_info["index"],
      tex_coord: texture_info["texCoord"] || 0,
      strength: texture_info["strength"] || 1.0,
      extensions: texture_info["extensions"],
      extras: texture_info["extras"]
    }
  end

  @doc """
  Parses textures array from glTF JSON data.

  ## Examples

      iex> textures_data = [%{"source" => 0, "sampler" => 0}]
      iex> AriaGltf.Import.Parser.Material.parse_textures(textures_data)
      [%AriaGltf.Texture{source: 0, sampler: 0}]
  """
  @spec parse_textures(list() | nil) :: [Texture.t()]
  def parse_textures(nil), do: []

  def parse_textures(textures_data) when is_list(textures_data) do
    Enum.map(textures_data, &parse_texture/1)
  end

  @spec parse_texture(map()) :: Texture.t()
  defp parse_texture(texture_data) when is_map(texture_data) do
    %Texture{
      name: texture_data["name"],
      sampler: texture_data["sampler"],
      source: texture_data["source"],
      extensions: texture_data["extensions"],
      extras: texture_data["extras"]
    }
  end

  @doc """
  Parses images array from glTF JSON data.

  ## Examples

      iex> images_data = [%{"uri" => "texture.png", "mimeType" => "image/png"}]
      iex> AriaGltf.Import.Parser.Material.parse_images(images_data)
      [%AriaGltf.Image{uri: "texture.png", mime_type: "image/png"}]
  """
  @spec parse_images(list() | nil) :: [Image.t()]
  def parse_images(nil), do: []

  def parse_images(images_data) when is_list(images_data) do
    Enum.map(images_data, &parse_image/1)
  end

  @spec parse_image(map()) :: Image.t()
  defp parse_image(image_data) when is_map(image_data) do
    %Image{
      name: image_data["name"],
      uri: image_data["uri"],
      mime_type: image_data["mimeType"],
      buffer_view: image_data["bufferView"],
      extensions: image_data["extensions"],
      extras: image_data["extras"]
    }
  end

  @doc """
  Parses samplers array from glTF JSON data.

  ## Examples

      iex> samplers_data = [%{"magFilter" => 9729, "minFilter" => 9987}]
      iex> AriaGltf.Import.Parser.Material.parse_samplers(samplers_data)
      [%AriaGltf.Sampler{mag_filter: 9729, min_filter: 9987}]
  """
  @spec parse_samplers(list() | nil) :: [Sampler.t()]
  def parse_samplers(nil), do: []

  def parse_samplers(samplers_data) when is_list(samplers_data) do
    Enum.map(samplers_data, &parse_sampler/1)
  end

  @spec parse_sampler(map()) :: Sampler.t()
  defp parse_sampler(sampler_data) when is_map(sampler_data) do
    %Sampler{
      name: sampler_data["name"],
      mag_filter: sampler_data["magFilter"],
      min_filter: sampler_data["minFilter"],
      # REPEAT
      wrap_s: sampler_data["wrapS"] || 10_497,
      # REPEAT
      wrap_t: sampler_data["wrapT"] || 10_497,
      extensions: sampler_data["extensions"],
      extras: sampler_data["extras"]
    }
  end
end
