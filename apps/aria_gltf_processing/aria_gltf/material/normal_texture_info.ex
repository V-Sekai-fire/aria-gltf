# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Material.NormalTextureInfo do
  @moduledoc """
  Reference to a normal texture with additional scale parameter.
  """

  @type t :: %__MODULE__{
          index: non_neg_integer(),
          tex_coord: non_neg_integer(),
          scale: number(),
          extensions: map() | nil,
          extras: any() | nil
        }

  @enforce_keys [:index]
  defstruct [
    :index,
    :extensions,
    :extras,
    tex_coord: 0,
    scale: 1.0
  ]

  @doc """
  Creates a new NormalTextureInfo struct.
  """
  @spec new(non_neg_integer(), keyword()) :: t()
  def new(index, opts \\ []) when is_integer(index) and index >= 0 do
    %__MODULE__{
      index: index,
      tex_coord: Keyword.get(opts, :tex_coord, 0),
      scale: Keyword.get(opts, :scale, 1.0),
      extensions: Keyword.get(opts, :extensions),
      extras: Keyword.get(opts, :extras)
    }
  end

  @doc """
  Validates a NormalTextureInfo struct.
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = texture) do
    with :ok <- validate_index(texture.index),
         :ok <- validate_tex_coord(texture.tex_coord),
         :ok <- validate_scale(texture.scale) do
      :ok
    end
  end

  @doc """
  Converts a NormalTextureInfo struct to a map.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = texture) do
    %{}
    |> Map.put("index", texture.index)
    |> put_if_present("texCoord", texture.tex_coord, 0)
    |> put_if_present("scale", texture.scale, 1.0)
    |> put_if_present("extensions", texture.extensions)
    |> put_if_present("extras", texture.extras)
  end

  @doc """
  Creates a NormalTextureInfo struct from a map.
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(map) when is_map(map) do
    with {:ok, index} <- get_required_field(map, "index") do
      texture = %__MODULE__{
        index: index,
        tex_coord: Map.get(map, "texCoord", 0),
        scale: Map.get(map, "scale", 1.0),
        extensions: Map.get(map, "extensions"),
        extras: Map.get(map, "extras")
      }

      case validate(texture) do
        :ok -> {:ok, texture}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Private validation functions

  defp validate_index(index) when is_integer(index) and index >= 0, do: :ok
  defp validate_index(_), do: {:error, "index must be non-negative integer"}

  defp validate_tex_coord(tex_coord) when is_integer(tex_coord) and tex_coord >= 0, do: :ok
  defp validate_tex_coord(_), do: {:error, "tex_coord must be non-negative integer"}

  defp validate_scale(scale) when is_number(scale), do: :ok
  defp validate_scale(_), do: {:error, "scale must be a number"}

  # Helper functions

  defp put_if_present(map, _key, value, default) when value == default, do: map
  defp put_if_present(map, key, value, _default), do: Map.put(map, key, value)
  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  defp get_required_field(map, key) do
    case Map.get(map, key) do
      nil -> {:error, "Missing required field: #{key}"}
      value -> {:ok, value}
    end
  end
end
