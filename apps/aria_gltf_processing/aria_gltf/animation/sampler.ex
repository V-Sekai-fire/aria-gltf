# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Animation.Sampler do
  @moduledoc """
  An animation sampler combines input and output accessors with an interpolation algorithm to define a keyframe graph.

  This module represents a glTF animation sampler as defined in the glTF 2.0 specification.
  A sampler defines how to interpolate between keyframes using input (time) and output (value) data.
  """

  @type interpolation_t :: :linear | :step | :cubicspline

  @type t :: %__MODULE__{
          input: non_neg_integer(),
          output: non_neg_integer(),
          interpolation: interpolation_t(),
          extensions: map() | nil,
          extras: any() | nil
        }

  @enforce_keys [:input, :output]
  defstruct [
    :input,
    :output,
    :interpolation,
    :extensions,
    :extras
  ]

  @valid_interpolations [:linear, :step, :cubicspline]

  @doc """
  Creates a new animation sampler with the required input and output accessor indices.
  """
  @spec new(non_neg_integer(), non_neg_integer(), interpolation_t()) :: t()
  def new(input_index, output_index, interpolation \\ :linear)
      when is_integer(input_index) and input_index >= 0 and
             is_integer(output_index) and output_index >= 0 and
             interpolation in @valid_interpolations do
    %__MODULE__{
      input: input_index,
      output: output_index,
      interpolation: interpolation
    }
  end

  @doc """
  Parses an animation sampler from JSON data.
  """
  @spec from_json(map()) :: {:ok, t()} | {:error, term()}
  def from_json(json) when is_map(json) do
    with {:ok, input} <- parse_input(json),
         {:ok, output} <- parse_output(json),
         {:ok, interpolation} <- parse_interpolation(json) do
      sampler = %__MODULE__{
        input: input,
        output: output,
        interpolation: interpolation,
        extensions: Map.get(json, "extensions"),
        extras: Map.get(json, "extras")
      }

      {:ok, sampler}
    end
  end

  defp parse_input(%{"input" => input}) when is_integer(input) and input >= 0 do
    {:ok, input}
  end

  defp parse_input(_), do: {:error, :missing_or_invalid_input}

  defp parse_output(%{"output" => output}) when is_integer(output) and output >= 0 do
    {:ok, output}
  end

  defp parse_output(_), do: {:error, :missing_or_invalid_output}

  defp parse_interpolation(%{"interpolation" => interpolation_string})
       when is_binary(interpolation_string) do
    case String.upcase(interpolation_string) do
      "LINEAR" -> {:ok, :linear}
      "STEP" -> {:ok, :step}
      "CUBICSPLINE" -> {:ok, :cubicspline}
      _ -> {:error, :invalid_interpolation}
    end
  end

  defp parse_interpolation(_) do
    # Default interpolation is LINEAR
    {:ok, :linear}
  end

  @doc """
  Converts the animation sampler to JSON format.
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = sampler) do
    json = %{
      "input" => sampler.input,
      "output" => sampler.output
    }

    json
    |> put_if_present("interpolation", interpolation_to_string(sampler.interpolation))
    |> put_if_present("extensions", sampler.extensions)
    |> put_if_present("extras", sampler.extras)
  end

  defp interpolation_to_string(:linear), do: "LINEAR"
  defp interpolation_to_string(:step), do: "STEP"
  defp interpolation_to_string(:cubicspline), do: "CUBICSPLINE"

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, _key, :linear), do: map # LINEAR is default, don't include
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  @doc """
  Gets the input accessor index for this sampler.
  """
  @spec input_index(t()) :: non_neg_integer()
  def input_index(%__MODULE__{input: input}), do: input

  @doc """
  Gets the output accessor index for this sampler.
  """
  @spec output_index(t()) :: non_neg_integer()
  def output_index(%__MODULE__{output: output}), do: output

  @doc """
  Gets the interpolation method for this sampler.
  """
  @spec interpolation(t()) :: interpolation_t()
  def interpolation(%__MODULE__{interpolation: interpolation}), do: interpolation

  @doc """
  Validates the animation sampler structure.
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE___{input: input, output: output, interpolation: interpolation}) do
    with :ok <- validate_accessor_index(input, :input),
         :ok <- validate_accessor_index(output, :output),
         :ok <- validate_interpolation(interpolation) do
    end
  end

  defp validate_accessor_index(index, _type) when is_integer(index) and index >= 0, do: :ok
  defp validate_accessor_index(_, type), do: {:error, {:invalid_accessor_index, type}}

  defp validate_interpolation(interpolation) when interpolation in @valid_interpolations, do: :ok
  defp validate_interpolation(_), do: {:error, :invalid_interpolation}

  @doc """
  Returns the list of valid interpolation methods.
  """
  @spec valid_interpolations() :: [interpolation_t()]
  def valid_interpolations, do: @valid_interpolations

  @doc """
  Gets the maximum time value from the input accessor.
  This is a placeholder that would need access to the actual accessor data.
  """
  @spec max_time(t()) :: float()
  def max_time(%__MODULE__{}) do
    raise "TODO: Implement #{__MODULE__}.max_time"
  end
end
