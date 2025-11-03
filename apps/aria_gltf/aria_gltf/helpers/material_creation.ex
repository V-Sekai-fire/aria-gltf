# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Helpers.MaterialCreation do
  @moduledoc """
  Helper functions for creating glTF materials.

  This module provides utilities for creating PBR (Physically Based Rendering)
  materials with various properties and texture configurations.
  """

  alias AriaGltf.Material

  @doc """
  Creates a basic PBR material.

  ## Options

  - `:name` - Material name
  - `:base_color_factor` - Base color [r, g, b, a] (default: [1, 1, 1, 1])
  - `:metallic_factor` - Metallic factor (default: 1.0)
  - `:roughness_factor` - Roughness factor (default: 1.0)
  - `:base_color_texture` - Base color texture index
  - `:metallic_roughness_texture` - Metallic-roughness texture index
  - `:normal_texture` - Normal texture index
  - `:emissive_factor` - Emissive factor [r, g, b]
  - `:alpha_mode` - Alpha mode ("OPAQUE", "MASK", "BLEND")
  - `:alpha_cutoff` - Alpha cutoff value
  - `:double_sided` - Double-sided flag

  ## Examples

      iex> material = AriaGltf.Helpers.MaterialCreation.create_pbr_material(name: "Red Metal")
      iex> material.name
      "Red Metal"
      iex> material.pbr_metallic_roughness.metallic_factor
      1.0

      iex> material = AriaGltf.Helpers.MaterialCreation.create_pbr_material(
      ...>   name: "Blue Plastic",
      ...>   base_color_factor: [0, 0, 1, 1],
      ...>   metallic_factor: 0.0,
      ...>   roughness_factor: 0.8,
      ...>   double_sided: true
      ...> )
      iex> material.name
      "Blue Plastic"
      iex> material.double_sided
      true
      iex> material.pbr_metallic_roughness.base_color_factor
      [0, 0, 1, 1]
  """
  @spec create_pbr_material(keyword()) :: Material.t()
  def create_pbr_material(opts \\ []) do
    name = Keyword.get(opts, :name)
    base_color_factor = Keyword.get(opts, :base_color_factor, [1, 1, 1, 1])
    metallic_factor = Keyword.get(opts, :metallic_factor, 1.0)
    roughness_factor = Keyword.get(opts, :roughness_factor, 1.0)
    base_color_texture = Keyword.get(opts, :base_color_texture)
    metallic_roughness_texture = Keyword.get(opts, :metallic_roughness_texture)
    normal_texture = Keyword.get(opts, :normal_texture)
    emissive_factor = Keyword.get(opts, :emissive_factor)
    alpha_mode = Keyword.get(opts, :alpha_mode)
    alpha_cutoff = Keyword.get(opts, :alpha_cutoff)
    double_sided = Keyword.get(opts, :double_sided)

    pbr = %Material.PbrMetallicRoughness{
      base_color_factor: base_color_factor,
      metallic_factor: metallic_factor,
      roughness_factor: roughness_factor,
      base_color_texture: if(base_color_texture, do: %{index: base_color_texture}),
      metallic_roughness_texture:
        if(metallic_roughness_texture, do: %{index: metallic_roughness_texture})
    }

    %Material{
      name: name,
      pbr_metallic_roughness: pbr,
      normal_texture: if(normal_texture, do: %{index: normal_texture}),
      emissive_factor: emissive_factor,
      alpha_mode: alpha_mode,
      alpha_cutoff: alpha_cutoff,
      double_sided: double_sided
    }
  end
end
