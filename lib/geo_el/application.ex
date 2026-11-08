defmodule GeoEl.Application do
  @moduledoc false

  use Application

  alias GeoEl.Globe.WorldData

  @impl true
  def start(_type, _args) do
    :ok = WorldData.load_into_persistent_term!()

    children = [
      GeoElWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:geo_el, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GeoEl.PubSub},
      {Registry, keys: :unique, name: GeoEl.Adventure.Registry},
      {DynamicSupervisor, name: GeoEl.Adventure.Supervisor, strategy: :one_for_one},
      GeoElWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: GeoEl.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    GeoElWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

