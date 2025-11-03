# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Animation do
  @moduledoc """
  A keyframe animation.

  This module represents a glTF animation as defined in the glTF 2.0 specification.
  An animation contains channels and samplers that define how properties of nodes
  change over time.
  """

  alias AriaGltf.Animation.{Channel, Sampler}

  @type t :: %__MODULE__{
          channels: [Channel.t()],
          samplers: [Sampler.t()],
          name: String.t() | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  @enforce_keys [:channels, :samplers]
  defstruct [
    :channels,
    :samplers,
    :name,
    :extensions,
    :extras
  ]

  @doc """
  Creates a new animation with the required channels and samplers.
  """
  @spec new([Channel.t()], [Sampler.t()]) :: t()
  def new(channels, samplers) when is_list(channels) and is_list(samplers) do
    %__MODULE__{
      channels: channels,
      samplers: samplers
    }
  end

  @doc """
  Creates a new animation with channels, samplers, and options.
  """
  @spec new([Channel.t()], [Sampler.t()], map()) :: t()
  def new(channels, samplers, options)
      when is_list(channels) and is_list(samplers) and is_map(options) do
    %__MODULE__{
      channels: channels,
      samplers: samplers,
      name: Map.get(options, :name),
      extensions: Map.get(options, :extensions),
      extras: Map.get(options, :extras)
    }
  end

  @doc """
  Parses an animation from JSON data.
  """
  @spec from_json(map()) :: {:ok, t()} | {:error, term()}
  def from_json(json) when is_map(json) do
    with {:ok, channels} <- parse_channels(json),
         {:ok, samplers} <- parse_samplers(json) do
      animation = %__MODULE__{
        channels: channels,
        samplers: samplers,
        name: Map.get(json, "name"),
        extensions: Map.get(json, "extensions"),
        extras: Map.get(json, "extras")
      }

      {:ok, animation}
    end
  end

  defp parse_channels(%{"channels" => channels_json}) when is_list(channels_json) do
    channels = Enum.map(channels_json, &Channel.from_json/1)

    if Enum.all?(channels, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(channels, fn {:ok, channel} -> channel end)}
    else
      {:error, :invalid_channels}
    end
  end

  defp parse_channels(_), do: {:error, :missing_channels}

  defp parse_samplers(%{"samplers" => samplers_json}) when is_list(samplers_json) do
    samplers = Enum.map(samplers_json, &Sampler.from_json/1)

    if Enum.all?(samplers, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(samplers, fn {:ok, sampler} -> sampler end)}
    else
      {:error, :invalid_samplers}
    end
  end

  defp parse_samplers(_), do: {:error, :missing_samplers}

  @doc """
  Converts the animation to JSON format.
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = animation) do
    json = %{
      "channels" => Enum.map(animation.channels, &Channel.to_json/1),
      "samplers" => Enum.map(animation.samplers, &Sampler.to_json/1)
    }

    json
    |> put_if_present("name", animation.name)
    |> put_if_present("extensions", animation.extensions)
    |> put_if_present("extras", animation.extras)
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  @doc """
  Gets the duration of the animation in seconds.
  """
  @spec duration(t()) :: float()
  def duration(%__MODULE__{samplers: samplers}) do
    samplers
    |> Enum.map(&Sampler.max_time/1)
    |> Enum.max(fn -> 0.0 end)
  end

  @doc """
  Validates the animation structure and references.
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{channels: channels, samplers: samplers}) do
    with :ok <- validate_channels(channels),
         :ok <- validate_samplers(samplers),
         :ok <- validate_channel_sampler_references(channels, samplers) do
      :ok
    end
  end

  defp validate_channels(channels) do
    if Enum.all?(channels, &Channel.validate/1) do
      :ok
    else
      {:error, :invalid_channels}
    end
  end

  defp validate_samplers(samplers) do
    if Enum.all?(samplers, &Sampler.validate/1) do
      :ok
    else
      {:error, :invalid_samplers}
    end
  end

  defp validate_channel_sampler_references(channels, samplers) do
    sampler_count = length(samplers)

    invalid_refs =
      channels
      |> Enum.filter(fn channel ->
        Channel.sampler_index(channel) >= sampler_count
      end)

    if Enum.empty?(invalid_refs) do
      :ok
    else
      {:error, :invalid_sampler_references}
    end
  end
end
