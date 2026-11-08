defmodule GeoEl do
  @moduledoc """
  Public entry points for starting and interacting with supervised globe adventure sessions.
  """

  alias GeoEl.Adventure.SessionServer
  alias GeoEl.Adventure.SessionState

  @doc """
  Starts or retrieves an isolated adventure session worker under the DynamicSupervisor swarm.
  """
  @spec ensure_session_started(String.t(), keyword()) :: {:ok, pid()}
  def ensure_session_started(session_id, opts \\ []) when is_binary(session_id) do
    child_opts = Keyword.put(opts, :session_id, session_id)

    case Registry.lookup(GeoEl.Adventure.Registry, session_id) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        case DynamicSupervisor.start_child(
               GeoEl.Adventure.Supervisor,
               {SessionServer, child_opts}
             ) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
        end
    end
  end

  @spec get_session_state(String.t()) :: SessionState.t()
  def get_session_state(session_id) when is_binary(session_id) do
    {:ok, pid} = ensure_session_started(session_id)
    SessionServer.get_state(pid)
  end
end

