defmodule Harnex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Harnex.RunStore,
      {Task.Supervisor, name: Harnex.TaskSupervisor},
      {Registry, keys: :unique, name: Harnex.RunRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Harnex.RunSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :rest_for_one, name: Harnex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
