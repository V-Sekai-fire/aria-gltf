# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Material.PbrMetallicRoughness do
  @moduledoc """
  A set of parameter values that are used to define the metallic-roughness material model
  from Physically-Based Rendering (PBR) methodology.
  """

  alias AriaGltf.TextureInfo

  @type t :: %__MODULE__{
          base_color_factor: [number()],
          base_color_texture: TextureInfo.t() | nil,
          metallic_factor: number(),
          roughness_factor: number(),
          metallic_roughness_texture: TextureInfo.t() | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  defstruct [
    :base_color_texture,
    :metallic_roughness_texture,
    :extensions,
    :extras,
    base_color_factor: [1.0, 1.0, 1.0, 1.0],
    metallic_factor: 1.0,
    roughness_factor: 1.0
  ]

  @doc """
  Creates a new PbrMetallicRoughness struct.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      base_color_factor: Keyword.get(opts, :base_color_factor, [1.0, 1.0, 1.0, 1.0]),
      base_color_texture: Keyword.get(opts, :base_color_texture),
      metallic_factor: Keyword.get(opts, :metallic_factor, 1.0),
      roughness_factor: Keyword.get(opts, :roughness_factor, 1.0),
      metallic_roughness_texture: Keyword.get(opts, :metallic_roughness_texture),
      extensions: Keyword.get(opts, :extensions),
      extras: Keyword.get(opts, :extras)
    }
  end

  @doc """
  Validates a PbrMetallicRoughness struct.
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = pbr) do
    with :ok <- validate_base_color_factor(pbr.base_color_factor),
         :ok <- validate_metallic_factor(pbr.metallic_factor),
         :ok <- validate_roughness_factor(pbr.roughness_factor),
         :ok <- validate_base_color_texture(pbr.base_color_texture),
         :ok <- validate_metallic_roughness_texture(pbr.metallic_roughness_texture) do
      :ok
    end
  end

  @doc """
  Converts a PbrMetallicRoughness struct to a map.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = pbr) do
    %{}
    |> put_if_present("baseColorFactor", pbr.base_color_factor, [1.0, 1.0, 1.0, 1.0])
    |> put_if_present("baseColorTexture", pbr.base_color_texture, &TextureInfo.to_map/1)
    |> put_if_present("metallicFactor", pbr.metallic_factor, 1.0)
    |> put_if_present("roughnessFactor", pbr.roughness_factor, 1.0)
    |> put_if_present(
      "metallicRoughnessTexture",
      pbr.metallic_roughness_texture,
      &TextureInfo.to_map/1
    )
    |> put_if_present("extensions", pbr.extensions)
    |> put_if_present("extras", pbr.extras)
  end

  @doc """
  Creates a PbrMetallicRoughness struct from a map.
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(map) when is_map(map) do
    with {:ok, base_color_texture} <- parse_texture_info(Map.get(map, "baseColorTexture")),
         {:ok, metallic_roughness_texture} <-
           parse_texture_info(Map.get(map, "metallicRoughnessTexture")) do
      pbr = %__MODULE__{
        base_color_factor: Map.get(map, "baseColorFactor", [1.0, 1.0, 1.0, 1.0]),
        base_color_texture: base_color_texture,
        metallic_factor: Map.get(map, "metallicFactor", 1.0),
        roughness_factor: Map.get(map, "roughnessFactor", 1.0),
        metallic_roughness_texture: metallic_roughness_texture,
        extensions: Map.get(map, "extensions"),
        extras: Map.get(map, "extras")
      }

      case validate(pbr) do
        :ok -> {:ok, pbr}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Private validation functions

  defp validate_base_color_factor(factor) when is_list(factor) and length(factor) == 4 do
    if Enum.all?(factor, fn x -> is_number(x) and x >= 0.0 and x <= 1.0 end) do
      :ok
    else
      {:error, "base_color_factor values must be between 0.0 and 1.0"}
    end
  end

  defp validate_base_color_factor(_), do: {:error, "base_color_factor must be array of 4 numbers"}

  defp validate_metallic_factor(factor)
       when is_number(factor) and factor >= 0.0 and factor <= 1.0,
       do: :ok

  defp validate_metallic_factor(_), do: {:error, "metallic_factor must be between 0.0 and 1.0"}

  defp validate_roughness_factor(factor)
       when is_number(factor) and factor >= 0.0 and factor <= 1.0,
       do: :ok

  defp validate_roughness_factor(_), do: {:error, "roughness_factor must be between 0.0 and 1.0"}

  defp validate_base_color_texture(nil), do: :ok

  defp validate_base_color_texture(%TextureInfo{} = texture) do
    TextureInfo.validate(texture)
  end

  defp validate_base_color_texture(_),
    do: {:error, "base_color_texture must be TextureInfo struct"}

  defp validate_metallic_roughness_texture(nil), do: :ok

  defp validate_metallic_roughness_texture(%TextureInfo{} = texture) do
    TextureInfo.validate(texture)
  end

  defp validate_metallic_roughness_texture(_),
    do: {:error, "metallic_roughness_texture must be TextureInfo struct"}

  # Helper functions

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  defp put_if_present(map, key, value, transform_fn) when is_function(transform_fn, 1),
    do: Map.put(map, key, transform_fn.(value))

  defp put_if_present(map, _key, value, default) when value == default, do: map
  defp put_if_present(map, key, value, _default), do: Map.put(map, key, value)

  defp parse_texture_info(nil), do: {:ok, nil}

  defp parse_texture_info(data) when is_map(data) do
    TextureInfo.from_map(data)
  end
end
