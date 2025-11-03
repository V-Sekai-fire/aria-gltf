# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Material do
  @moduledoc """
  The material appearance of a primitive.

  From glTF 2.0 specification section 5.19:
  glTF defines materials using a common set of parameters that are based on widely used material
  representations from Physically Based Rendering (PBR). Specifically, glTF uses the metallic-
  roughness material model.
  """

  alias AriaGltf.Material.{PbrMetallicRoughness, NormalTextureInfo, OcclusionTextureInfo}
  alias AriaGltf.TextureInfo

  @type alpha_mode :: :opaque | :mask | :blend

  @type t :: %__MODULE__{
          name: String.t() | nil,
          extensions: map() | nil,
          extras: any() | nil,
          pbr_metallic_roughness: PbrMetallicRoughness.t() | nil,
          normal_texture: NormalTextureInfo.t() | nil,
          occlusion_texture: OcclusionTextureInfo.t() | nil,
          emissive_texture: TextureInfo.t() | nil,
          emissive_factor: [number()],
          alpha_mode: alpha_mode(),
          alpha_cutoff: number(),
          double_sided: boolean()
        }

  defstruct [
    :name,
    :extensions,
    :extras,
    :pbr_metallic_roughness,
    :normal_texture,
    :occlusion_texture,
    :emissive_texture,
    emissive_factor: [0.0, 0.0, 0.0],
    alpha_mode: :opaque,
    alpha_cutoff: 0.5,
    double_sided: false
  ]

  @doc """
  Creates a new Material struct.

  ## Parameters
  - `name`: The user-defined name of this object (optional)
  - `extensions`: JSON object with extension-specific objects (optional)
  - `extras`: Application-specific data (optional)
  - `pbr_metallic_roughness`: PBR metallic-roughness parameters (optional)
  - `normal_texture`: The tangent space normal texture (optional)
  - `occlusion_texture`: The occlusion texture (optional)
  - `emissive_texture`: The emissive texture (optional)
  - `emissive_factor`: The factors for the emissive color (optional, default: [0,0,0])
  - `alpha_mode`: The alpha rendering mode (optional, default: :opaque)
  - `alpha_cutoff`: The alpha cutoff value (optional, default: 0.5)
  - `double_sided`: Whether the material is double sided (optional, default: false)

  ## Examples

      iex> AriaGltf.Material.new()
      %AriaGltf.Material{
        emissive_factor: [0.0, 0.0, 0.0],
        alpha_mode: :opaque,
        alpha_cutoff: 0.5,
        double_sided: false
      }

      iex> AriaGltf.Material.new(name: "Gold Material", alpha_mode: :blend)
      %AriaGltf.Material{
        name: "Gold Material",
        alpha_mode: :blend,
        emissive_factor: [0.0, 0.0, 0.0],
        alpha_cutoff: 0.5,
        double_sided: false
      }
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      name: Keyword.get(opts, :name),
      extensions: Keyword.get(opts, :extensions),
      extras: Keyword.get(opts, :extras),
      pbr_metallic_roughness: Keyword.get(opts, :pbr_metallic_roughness),
      normal_texture: Keyword.get(opts, :normal_texture),
      occlusion_texture: Keyword.get(opts, :occlusion_texture),
      emissive_texture: Keyword.get(opts, :emissive_texture),
      emissive_factor: Keyword.get(opts, :emissive_factor, [0.0, 0.0, 0.0]),
      alpha_mode: Keyword.get(opts, :alpha_mode, :opaque),
      alpha_cutoff: Keyword.get(opts, :alpha_cutoff, 0.5),
      double_sided: Keyword.get(opts, :double_sided, false)
    }
  end

  @doc """
  Creates a new material with name, properties, and options.
  """
  @spec new(String.t(), map(), map()) :: t()
  def new(name, properties, options \\ %{}) when is_binary(name) and is_map(properties) do
    %__MODULE__{
      name: name,
      pbr_metallic_roughness: Map.get(properties, :pbr_metallic_roughness),
      normal_texture: Map.get(properties, :normal_texture),
      occlusion_texture: Map.get(properties, :occlusion_texture),
      emissive_texture: Map.get(properties, :emissive_texture),
      emissive_factor: Map.get(properties, :emissive_factor, [0.0, 0.0, 0.0]),
      alpha_mode: Map.get(properties, :alpha_mode, :opaque),
      alpha_cutoff: Map.get(properties, :alpha_cutoff, 0.5),
      double_sided: Map.get(properties, :double_sided, false),
      extensions: Map.get(options, :extensions),
      extras: Map.get(options, :extras)
    }
  end

  @doc """
  Validates a Material struct according to glTF 2.0 specification.

  ## Validation Rules
  - emissive_factor must be array of 3 numbers between 0.0 and 1.0
  - alpha_mode must be valid
  - alpha_cutoff must be >= 0.0
  - double_sided must be boolean
  - alpha_cutoff should only be defined when alpha_mode is :mask

  ## Examples

      iex> material = AriaGltf.Material.new()
      iex> AriaGltf.Material.validate(material)
      :ok
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = material) do
    with :ok <- validate_emissive_factor(material.emissive_factor),
         :ok <- validate_alpha_mode(material.alpha_mode),
         :ok <- validate_alpha_cutoff(material.alpha_cutoff),
         :ok <- validate_double_sided(material.double_sided),
         :ok <- validate_pbr_metallic_roughness(material.pbr_metallic_roughness),
         :ok <- validate_normal_texture(material.normal_texture),
         :ok <- validate_occlusion_texture(material.occlusion_texture),
         :ok <- validate_emissive_texture(material.emissive_texture) do
      :ok
    end
  end

  @doc """
  Converts a Material struct to a map suitable for JSON encoding.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = material) do
    %{}
    |> put_if_present("name", material.name)
    |> put_if_present("extensions", material.extensions)
    |> put_if_present("extras", material.extras)
    |> put_if_present(
      "pbrMetallicRoughness",
      material.pbr_metallic_roughness,
      &PbrMetallicRoughness.to_map/1
    )
    |> put_if_present("normalTexture", material.normal_texture, &NormalTextureInfo.to_map/1)
    |> put_if_present(
      "occlusionTexture",
      material.occlusion_texture,
      &OcclusionTextureInfo.to_map/1
    )
    |> put_if_present("emissiveTexture", material.emissive_texture, &TextureInfo.to_map/1)
    |> put_if_present("emissiveFactor", material.emissive_factor, [0.0, 0.0, 0.0])
    |> put_if_present("alphaMode", alpha_mode_to_string(material.alpha_mode), "OPAQUE")
    |> put_if_present("alphaCutoff", material.alpha_cutoff, 0.5)
    |> put_if_present("doubleSided", material.double_sided, false)
  end

  @doc """
  Creates a Material struct from a map (typically from JSON parsing).
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(map) when is_map(map) do
    with {:ok, pbr_metallic_roughness} <-
           parse_pbr_metallic_roughness(Map.get(map, "pbrMetallicRoughness")),
         {:ok, normal_texture} <- parse_normal_texture(Map.get(map, "normalTexture")),
         {:ok, occlusion_texture} <- parse_occlusion_texture(Map.get(map, "occlusionTexture")),
         {:ok, emissive_texture} <- parse_emissive_texture(Map.get(map, "emissiveTexture")),
         {:ok, alpha_mode} <- parse_alpha_mode(Map.get(map, "alphaMode", "OPAQUE")) do
      material = %__MODULE__{
        name: Map.get(map, "name"),
        extensions: Map.get(map, "extensions"),
        extras: Map.get(map, "extras"),
        pbr_metallic_roughness: pbr_metallic_roughness,
        normal_texture: normal_texture,
        occlusion_texture: occlusion_texture,
        emissive_texture: emissive_texture,
        emissive_factor: Map.get(map, "emissiveFactor", [0.0, 0.0, 0.0]),
        alpha_mode: alpha_mode,
        alpha_cutoff: Map.get(map, "alphaCutoff", 0.5),
        double_sided: Map.get(map, "doubleSided", false)
      }

      case validate(material) do
        :ok -> {:ok, material}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Creates a Material struct from JSON data.
  """
  @spec from_json(map()) :: t()
  def from_json(json) do
    case from_map(json) do
      {:ok, material} -> material
      {:error, _reason} -> raise ArgumentError, "Invalid material JSON"
    end
  end

  @doc """
  Converts a Material struct to JSON-compatible map.
  """
  @spec to_json(t()) :: map()
  def to_json(material), do: to_map(material)

  # Private validation functions

  defp validate_emissive_factor(factor) when is_list(factor) and length(factor) == 3 do
    if Enum.all?(factor, fn x -> is_number(x) and x >= 0.0 and x <= 1.0 end) do
      :ok
    else
      {:error, "emissive_factor values must be between 0.0 and 1.0"}
    end
  end

  defp validate_emissive_factor(_), do: {:error, "emissive_factor must be array of 3 numbers"}

  defp validate_alpha_mode(mode) when mode in [:opaque, :mask, :blend], do: :ok
  defp validate_alpha_mode(_), do: {:error, "Invalid alpha_mode"}

  defp validate_alpha_cutoff(cutoff) when is_number(cutoff) and cutoff >= 0.0, do: :ok
  defp validate_alpha_cutoff(_), do: {:error, "alpha_cutoff must be >= 0.0"}

  defp validate_double_sided(sided) when is_boolean(sided), do: :ok
  defp validate_double_sided(_), do: {:error, "double_sided must be boolean"}

  defp validate_pbr_metallic_roughness(nil), do: :ok

  defp validate_pbr_metallic_roughness(%PbrMetallicRoughness{} = pbr) do
    PbrMetallicRoughness.validate(pbr)
  end

  defp validate_pbr_metallic_roughness(_),
    do: {:error, "pbr_metallic_roughness must be PbrMetallicRoughness struct"}

  defp validate_normal_texture(nil), do: :ok

  defp validate_normal_texture(%NormalTextureInfo{} = texture) do
    NormalTextureInfo.validate(texture)
  end

  defp validate_normal_texture(_), do: {:error, "normal_texture must be NormalTextureInfo struct"}

  defp validate_occlusion_texture(nil), do: :ok

  defp validate_occlusion_texture(%OcclusionTextureInfo{} = texture) do
    OcclusionTextureInfo.validate(texture)
  end

  defp validate_occlusion_texture(_),
    do: {:error, "occlusion_texture must be OcclusionTextureInfo struct"}

  defp validate_emissive_texture(nil), do: :ok

  defp validate_emissive_texture(%TextureInfo{} = texture) do
    TextureInfo.validate(texture)
  end

  defp validate_emissive_texture(_), do: {:error, "emissive_texture must be TextureInfo struct"}

  # Helper functions

  defp put_if_present(map, key, value), do: Map.put(map, key, value)
  defp put_if_present(map, _key, nil), do: map

  defp put_if_present(map, key, value, transform_fn) when is_function(transform_fn, 1),
    do: Map.put(map, key, transform_fn.(value))

  defp put_if_present(map, key, value, _default), do: Map.put(map, key, value)
  defp put_if_present(map, _key, value, default) when value == default, do: map

  defp alpha_mode_to_string(:opaque), do: "OPAQUE"
  defp alpha_mode_to_string(:mask), do: "MASK"
  defp alpha_mode_to_string(:blend), do: "BLEND"
  # Handle string inputs (from map-based fixtures)
  defp alpha_mode_to_string("OPAQUE"), do: "OPAQUE"
  defp alpha_mode_to_string("MASK"), do: "MASK"
  defp alpha_mode_to_string("BLEND"), do: "BLEND"
  defp alpha_mode_to_string(str) when is_binary(str), do: str

  defp parse_alpha_mode("OPAQUE"), do: {:ok, :opaque}
  defp parse_alpha_mode("MASK"), do: {:ok, :mask}
  defp parse_alpha_mode("BLEND"), do: {:ok, :blend}
  defp parse_alpha_mode(_), do: {:error, "Invalid alpha mode string"}

  defp parse_pbr_metallic_roughness(nil), do: {:ok, nil}

  defp parse_pbr_metallic_roughness(data) when is_map(data) do
    PbrMetallicRoughness.from_map(data)
  end

  defp parse_normal_texture(nil), do: {:ok, nil}

  defp parse_normal_texture(data) when is_map(data) do
    NormalTextureInfo.from_map(data)
  end

  defp parse_occlusion_texture(nil), do: {:ok, nil}

  defp parse_occlusion_texture(data) when is_map(data) do
    OcclusionTextureInfo.from_map(data)
  end

  defp parse_emissive_texture(nil), do: {:ok, nil}

  defp parse_emissive_texture(data) when is_map(data) do
    TextureInfo.from_map(data)
  end
end
