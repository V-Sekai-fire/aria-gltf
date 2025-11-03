# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Texture do
  @moduledoc """
  A texture and its sampler.
  """

  @type t :: %__MODULE__{
          sampler: non_neg_integer() | nil,
          source: non_neg_integer() | nil,
          name: String.t() | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  defstruct [
    :sampler,
    :source,
    :name,
    :extensions,
    :extras
  ]

  @doc """
  Creates a new texture.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new texture with source, sampler, and options.
  """
  def new(source, sampler, options \\ %{}) do
    %__MODULE__{
      source: source,
      sampler: sampler,
      name: Map.get(options, :name),
      extensions: Map.get(options, :extensions, %{}),
      extras: Map.get(options, :extras, %{})
    }
  end

  @doc """
  Validates texture data structure.
  """
  def validate(%__MODULE__{} = texture) do
    cond do
      is_nil(texture.source) ->
        {:error, "Texture must have a source"}

      true ->
        {:ok, texture}
    end
  end

  @doc """
  Creates texture from JSON data.
  """
  def from_json(json) when is_map(json) do
    %__MODULE__{
      source: Map.get(json, "source"),
      sampler: Map.get(json, "sampler"),
      name: Map.get(json, "name"),
      extensions: Map.get(json, "extensions", %{}),
      extras: Map.get(json, "extras", %{})
    }
  end

  @doc """
  Converts texture to JSON format.
  """
  def to_json(%__MODULE__{} = texture) do
    %{}
    |> put_if_present("source", texture.source)
    |> put_if_present("sampler", texture.sampler)
    |> put_if_present("name", texture.name)
    |> put_if_present("extensions", texture.extensions)
    |> put_if_present("extras", texture.extras)
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
end
