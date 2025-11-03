# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Sampler do
  @moduledoc """
  Texture sampler properties for filtering and wrapping modes.
  """

  @type t :: %__MODULE__{
          mag_filter: non_neg_integer() | nil,
          min_filter: non_neg_integer() | nil,
          wrap_s: non_neg_integer(),
          wrap_t: non_neg_integer(),
          name: String.t() | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  defstruct [
    :mag_filter,
    :min_filter,
    :name,
    :extensions,
    :extras,
    # GL_REPEAT
    wrap_s: 10_497,
    # GL_REPEAT
    wrap_t: 10_497
  ]

  @doc """
  Creates a new sampler with options.
  """
  def new(options \\ %{}) do
    %__MODULE__{
      mag_filter: Map.get(options, :mag_filter),
      min_filter: Map.get(options, :min_filter),
      wrap_s: Map.get(options, :wrap_s, 10_497),
      wrap_t: Map.get(options, :wrap_t, 10_497),
      name: Map.get(options, :name),
      extensions: Map.get(options, :extensions),
      extras: Map.get(options, :extras)
    }
  end

  @doc """
  Creates a Sampler struct from JSON data.
  """
  def from_json(json) when is_map(json) do
    %__MODULE__{
      mag_filter: Map.get(json, "magFilter"),
      min_filter: Map.get(json, "minFilter"),
      wrap_s: Map.get(json, "wrapS", 10_497),
      wrap_t: Map.get(json, "wrapT", 10_497),
      name: Map.get(json, "name"),
      extensions: Map.get(json, "extensions"),
      extras: Map.get(json, "extras")
    }
  end

  @doc """
  Converts a Sampler struct to JSON-compatible map.
  """
  def to_json(%__MODULE__{} = sampler) do
    %{}
    |> put_if_present("magFilter", sampler.mag_filter)
    |> put_if_present("minFilter", sampler.min_filter)
    |> put_if_present("wrapS", sampler.wrap_s, 10_497)
    |> put_if_present("wrapT", sampler.wrap_t, 10_497)
    |> put_if_present("name", sampler.name)
    |> put_if_present("extensions", sampler.extensions)
    |> put_if_present("extras", sampler.extras)
  end

  # Helper functions
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, _key, value, default) when value == default, do: map
  defp put_if_present(map, key, value, _default), do: Map.put(map, key, value)
end
