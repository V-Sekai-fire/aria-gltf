# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Validation.Warning do
  @moduledoc """
  Represents a validation warning found in a glTF document.

  Warnings indicate potential issues or non-standard constructs that
  don't prevent the document from being valid but may cause problems.
  """

  alias AriaGltf.Validation.Error

  @type location :: Error.location()

  @type t :: %__MODULE__{
          location: location(),
          message: String.t(),
          timestamp: DateTime.t()
        }

  defstruct [
    :location,
    :message,
    timestamp: nil
  ]

  @doc """
  Creates a new validation warning.
  """
  @spec new(location(), String.t()) :: t()
  def new(location, message) do
    %__MODULE__{
      location: location,
      message: message,
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Formats the location for display.
  """
  @spec format_location(location()) :: String.t()
  def format_location(location) do
    Error.format_location(location)
  end

  @doc """
  Converts the warning to a JSON-serializable map.
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = warning) do
    %{
      "location" => format_location(warning.location),
      "message" => warning.message,
      "severity" => "warning",
      "timestamp" => if(warning.timestamp, do: DateTime.to_iso8601(warning.timestamp))
    }
  end

  @doc """
  Formats the warning as a human-readable string.
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{} = warning) do
    location_str = format_location(warning.location)
    "WARNING at #{location_str}: #{warning.message}"
  end
end
