# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Validation.Error do
  @moduledoc """
  Represents a validation error found in a glTF document.

  Errors indicate violations of the glTF specification that prevent
  the document from being considered valid.
  """

  @type location :: atom() | {atom(), integer()} | [atom() | integer()]
  @type severity :: :critical | :error | :warning

  @type t :: %__MODULE__{
          location: location(),
          message: String.t(),
          severity: severity(),
          timestamp: DateTime.t()
        }

  defstruct [
    :location,
    :message,
    severity: :error,
    timestamp: nil
  ]

  @doc """
  Creates a new validation error.
  """
  @spec new(location(), String.t(), severity()) :: t()
  def new(location, message, severity \\ :error) do
    %__MODULE__{
      location: location,
      message: message,
      severity: severity,
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Checks if the error is critical (prevents document usage).
  """
  @spec critical?(t()) :: boolean()
  def critical?(%__MODULE__{severity: :critical}), do: true
  def critical?(%__MODULE__{}), do: false

  @doc """
  Formats the location for display.
  """
  @spec format_location(location()) :: String.t()
  def format_location(location) when is_atom(location) do
    Atom.to_string(location)
  end

  def format_location({field, index}) when is_atom(field) and is_integer(index) do
    "#{field}[#{index}]"
  end

  def format_location(path) when is_list(path) do
    Enum.map_join(path, ".", fn
      atom when is_atom(atom) -> Atom.to_string(atom)
      int when is_integer(int) -> "[#{int}]"
      str when is_binary(str) -> str
    end)
  end

  def format_location(other), do: inspect(other)

  @doc """
  Converts the error to a JSON-serializable map.
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = error) do
    %{
      "location" => format_location(error.location),
      "message" => error.message,
      "severity" => Atom.to_string(error.severity),
      "timestamp" => if(error.timestamp, do: DateTime.to_iso8601(error.timestamp))
    }
  end

  @doc """
  Formats the error as a human-readable string.
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{} = error) do
    severity_str = String.upcase(Atom.to_string(error.severity))
    location_str = format_location(error.location)
    "#{severity_str} at #{location_str}: #{error.message}"
  end
end
