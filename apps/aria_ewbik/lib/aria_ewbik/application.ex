# SPDX-License-Identifier: MIT
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaEwbik.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: AriaEwbik.Worker.start_link(arg)
      # {AriaEwbik.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AriaEwbik.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
