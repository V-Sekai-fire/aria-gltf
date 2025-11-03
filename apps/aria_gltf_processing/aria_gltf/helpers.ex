# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Helpers do
  @moduledoc """
  Helper functions for common glTF patterns and utilities.

  This module provides convenient functions for creating common glTF structures,
  generating meshes, setting up materials, and configuring animations. These
  helpers simplify the process of creating glTF documents programmatically.

  Functions are organized into specialized modules but delegated here for
  backward compatibility and convenience.
  """

  alias AriaGltf.Helpers.{
    DocumentCreation,
    MeshCreation,
    MaterialCreation,
    AnimationCreation,
    BufferManagement
  }

  # Document and Scene Creation
  defdelegate create_minimal_document(opts \\ []), to: DocumentCreation
  defdelegate create_simple_scene(opts \\ []), to: DocumentCreation
  defdelegate create_node(opts \\ []), to: DocumentCreation

  # Mesh Creation
  defdelegate create_simple_mesh(opts \\ []), to: MeshCreation
  defdelegate create_cube_mesh(opts \\ []), to: MeshCreation

  # Material Creation
  defdelegate create_pbr_material(opts \\ []), to: MaterialCreation

  # Animation Creation
  defdelegate create_simple_animation(opts \\ []), to: AnimationCreation

  # Buffer Management
  defdelegate create_buffer(opts \\ []), to: BufferManagement
  defdelegate create_buffer_view(opts \\ []), to: BufferManagement
  defdelegate create_accessor(opts \\ []), to: BufferManagement
end
