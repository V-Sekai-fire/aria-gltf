# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Asset do
  @moduledoc """
  Metadata about the glTF asset.

  This module represents the asset information as defined in the glTF 2.0 specification.
  The asset object contains metadata about the glTF asset.
  """

  @type t :: %__MODULE__{
          copyright: String.t() | nil,
          generator: String.t() | nil,
          version: String.t(),
          min_version: String.t() | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  @enforce_keys [:version]
  defstruct [
    :copyright,
    :generator,
    :version,
    :min_version,
    :extensions,
    :extras
  ]

  @doc """
  Creates a new asset with the required version.
  """
  @spec new(String.t()) :: t()
  def new(version) when is_binary(version) do
    %__MODULE__{version: version}
  end

  @doc """
  Creates a new asset with version 2.0 (the current glTF specification version).
  """
  @spec new() :: t()
  def new do
    new("2.0")
  end

  @doc """
  Creates a new asset with version, generator, and options.
  """
  @spec new(String.t(), String.t(), map()) :: t()
  def new(version, generator, options \\ %{}) when is_binary(version) and is_binary(generator) do
    %__MODULE__{
      version: version,
      generator: generator,
      copyright: Map.get(options, :copyright),
      min_version: Map.get(options, :min_version),
      extensions: Map.get(options, :extensions),
      extras: Map.get(options, :extras)
    }
  end

  @doc """
  Parses an asset from JSON data.
  """
  @spec from_json(map()) :: {:ok, t()} | {:error, term()}
  def from_json(%{"version" => version} = json) when is_binary(version) do
    asset = %__MODULE__{
      version: version,
      copyright: Map.get(json, "copyright"),
      generator: Map.get(json, "generator"),
      min_version: Map.get(json, "minVersion"),
      extensions: Map.get(json, "extensions"),
      extras: Map.get(json, "extras")
    }

    {:ok, asset}
  end

  def from_json(_), do: {:error, :missing_version}

  @doc """
  Converts the asset to JSON format.
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = asset) do
    json = %{"version" => asset.version}

    json
    |> put_if_present("copyright", asset.copyright)
    |> put_if_present("generator", asset.generator)
    |> put_if_present("minVersion", asset.min_version)
    |> put_if_present("extensions", asset.extensions)
    |> put_if_present("extras", asset.extras)
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  @doc """
  Validates that the version follows the required pattern.
  """
  @spec valid_version?(String.t()) :: boolean()
  def valid_version?(version) when is_binary(version) do
    Regex.match?(~r/^[0-9]+\.[0-9]+$/, version)
  end

  def valid_version?(_), do: false

  @doc """
  Validates that the min_version is not greater than the version.
  """
  @spec valid_min_version?(t()) :: boolean()
  def valid_min_version?(%__MODULE__{min_version: nil}), do: true

  def valid_min_version?(%__MODULE__{version: version, min_version: min_version}) do
    with true <- valid_version?(version),
         true <- valid_version?(min_version) do
      compare_versions(min_version, version) != :gt
    else
      _ -> false
    end
  end

  defp compare_versions(v1, v2) do
    [major1, minor1] = String.split(v1, ".") |> Enum.map(&String.to_integer/1)
    [major2, minor2] = String.split(v2, ".") |> Enum.map(&String.to_integer/1)

    cond do
      major1 > major2 -> :gt
      major1 < major2 -> :lt
      minor1 > minor2 -> :gt
      minor1 < minor2 -> :lt
      true -> :eq
    end
  end
end
