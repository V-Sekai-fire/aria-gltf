# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Import.Parser.Utility do
  @moduledoc """
  Utility parsers for common glTF data types.

  This module provides parsing functions for standard glTF data structures
  like matrices, quaternions, and vectors.
  """

  @doc """
  Parses a 4x4 transformation matrix.

  ## Examples

      iex> AriaGltf.Import.Parser.Utility.parse_matrix([1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1])
      [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]

      iex> AriaGltf.Import.Parser.Utility.parse_matrix(nil)
      nil
  """
  @spec parse_matrix(list() | nil) :: list() | nil
  def parse_matrix(nil), do: nil

  def parse_matrix(matrix) when is_list(matrix) and length(matrix) == 16 do
    matrix
  end

  @doc """
  Parses a quaternion rotation.

  ## Examples

      iex> AriaGltf.Import.Parser.Utility.parse_quaternion([0, 0, 0, 1])
      [0, 0, 0, 1]

      iex> AriaGltf.Import.Parser.Utility.parse_quaternion(nil)
      nil
  """
  @spec parse_quaternion(list() | nil) :: list() | nil
  def parse_quaternion(nil), do: nil

  def parse_quaternion(quat) when is_list(quat) and length(quat) == 4 do
    quat
  end

  @doc """
  Parses a 3D vector.

  ## Examples

      iex> AriaGltf.Import.Parser.Utility.parse_vec3([1.0, 2.0, 3.0])
      [1.0, 2.0, 3.0]

      iex> AriaGltf.Import.Parser.Utility.parse_vec3(nil)
      nil
  """
  @spec parse_vec3(list() | nil) :: list() | nil
  def parse_vec3(nil), do: nil

  def parse_vec3(vec) when is_list(vec) and length(vec) == 3 do
    vec
  end

  @doc """
  Parses a 4D vector.

  ## Examples

      iex> AriaGltf.Import.Parser.Utility.parse_vec4([1.0, 2.0, 3.0, 4.0])
      [1.0, 2.0, 3.0, 4.0]

      iex> AriaGltf.Import.Parser.Utility.parse_vec4(nil)
      nil
  """
  @spec parse_vec4(list() | nil) :: list() | nil
  def parse_vec4(nil), do: nil

  def parse_vec4(vec) when is_list(vec) and length(vec) == 4 do
    vec
  end
end
