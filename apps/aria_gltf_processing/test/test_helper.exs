# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

# Start required applications
{:ok, _} = Application.ensure_all_started(:aria_math)
{:ok, _} = Application.ensure_all_started(:aria_joint)

# Add compiled modules to code path if not already there
build_path = Path.join([__DIR__, "..", "..", "..", "_build", "test", "lib", "aria_gltf_processing", "ebin"])
if File.exists?(build_path) do
  Code.prepend_path(build_path)
end

# Test support modules are now compiled as part of the project
# No need to require them manually - they're available via normal compilation

# Load application spec (but don't start)
case Application.load(:aria_gltf_processing) do
  :ok -> :ok
  {:error, {:already_loaded, _}} -> :ok
  _error -> :ok  # Ignore other errors
end

# Configure Logger for verbose test output
Logger.configure(level: :debug)
Logger.configure_backend(:console, level: :debug)

# Start ExUnit with log capture enabled for detailed output
ExUnit.start(capture_log: true)

