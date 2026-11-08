defmodule GeoElWeb.GlobeLive do
  @moduledoc """
  Interactive Phoenix LiveView rendering the server-projected Orthographic SVG Globe,
  expedition clue HUD, SkewPNN/A2 telemetry, and geodesic trajectory stream.
  """

  use GeoElWeb, :live_view

  alias GeoEl.Adventure.Calibration
  alias GeoEl.Adventure.SessionServer
  alias GeoEl.Adventure.SessionState
  alias GeoEl.Globe.Coord
  alias GeoEl.Globe.Projection
  alias GeoEl.Globe.WorldData

  @svg_size 500
  @svg_center 250.0
  @globe_radius 220.0

  @impl true
  def mount(params, _session, socket) do
    session_id = Map.get(params, "session_id") || generate_session_id()
    {:ok, server_pid} = GeoEl.ensure_session_started(session_id, radius: @globe_radius)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(GeoEl.PubSub, SessionServer.pubsub_topic())
    end

    state = SessionServer.get_state(server_pid)

    socket =
      socket
      |> assign(:session_id, session_id)
      |> assign(:server_pid, server_pid)
      |> assign(:svg_size, @svg_size)
      |> assign(:svg_center, @svg_center)
      |> assign(:coord_form, to_form(%{"lat" => "0.0", "lon" => "0.0"}, as: :guess))
      |> assign(:legs_empty?, state.completed_legs == [])
      |> stream(:expedition_log, state.completed_legs, reset: true)
      |> assign_session_projection(state)

    {:ok, socket}
  end

  @impl true
  def handle_event("rotate_camera", %{"dlat" => dlat, "dlon" => dlon}, socket) do
    parsed_dlat = parse_float(dlat, 0.0)
    parsed_dlon = parse_float(dlon, 0.0)

    state = SessionServer.rotate_camera(socket.assigns.server_pid, parsed_dlat, parsed_dlon)
    {:noreply, assign_session_projection(socket, state)}
  end

  @impl true
  def handle_event("globe_click", %{"offset_x" => ox, "offset_y" => oy}, socket) do
    parsed_x = parse_float(ox, 0.0)
    parsed_y = parse_float(oy, 0.0)

    {:ok, state, leg_entry} =
      SessionServer.submit_viewport_click(socket.assigns.server_pid, parsed_x, parsed_y)

    socket =
      if is_nil(leg_entry) do
        assign_session_projection(socket, state)
      else
        socket
        |> assign(:legs_empty?, false)
        |> stream_insert(:expedition_log, leg_entry)
        |> assign_session_projection(state)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_guess", %{"guess" => %{"lat" => lat_str, "lon" => lon_str}}, socket) do
    lat = parse_float(lat_str, 0.0)
    lon = parse_float(lon_str, 0.0)
    guessed_coord = Coord.new(lat, lon)

    {:ok, state, leg_entry} =
      SessionServer.submit_coord_guess(socket.assigns.server_pid, guessed_coord)

    socket =
      if is_nil(leg_entry) do
        assign_session_projection(socket, state)
      else
        socket
        |> assign(:legs_empty?, false)
        |> stream_insert(:expedition_log, leg_entry)
        |> assign_session_projection(state)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("request_hint", _params, socket) do
    state = SessionServer.request_hint(socket.assigns.server_pid)
    {:noreply, assign_session_projection(socket, state)}
  end

  @impl true
  def handle_event("reset_expedition", _params, socket) do
    state = SessionServer.reset_expedition(socket.assigns.server_pid)

    socket =
      socket
      |> assign(:legs_empty?, true)
      |> stream(:expedition_log, [], reset: true)
      |> assign_session_projection(state)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:expedition_leg_completed, source_session_id, _leg_entry}, socket) do
    socket =
      if source_session_id == socket.assigns.session_id do
        socket
      else
        assign(socket, :peer_activity_session, source_session_id)
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="grid grid-cols-1 gap-8 lg:grid-cols-12 bg-white text-slate-900">
        <div class="lg:col-span-7 flex flex-col items-center rounded-xl border border-slate-200 bg-white p-6 shadow-xs">
          <div class="mb-3 flex w-full items-center justify-between border-b border-slate-100 pb-2">
            <div>
              <h1 class="text-base font-bold text-slate-900">
                Orthographic Spherical Viewport
              </h1>
              <p id="camera-telemetry" class="text-xs text-slate-600">
                Camera Center: {Float.round(@session_state.camera.lat, 1)} deg Lat, {Float.round(
                  @session_state.camera.lon,
                  1
                )} deg Lon
              </p>
            </div>
            <div class="flex items-center gap-1.5">
              <.button
                id="rotate-west-btn"
                phx-click="rotate_camera"
                phx-value-dlat="0"
                phx-value-dlon="-20"
              >
                West
              </.button>
              <.button
                id="rotate-north-btn"
                phx-click="rotate_camera"
                phx-value-dlat="15"
                phx-value-dlon="0"
              >
                North
              </.button>
              <.button
                id="rotate-south-btn"
                phx-click="rotate_camera"
                phx-value-dlat="-15"
                phx-value-dlon="0"
              >
                South
              </.button>
              <.button
                id="rotate-east-btn"
                phx-click="rotate_camera"
                phx-value-dlat="0"
                phx-value-dlon="20"
              >
                East
              </.button>
            </div>
          </div>

          <div
            id="globe-interaction-layer"
            phx-hook=".GlobeDrag"
            data-center-x={@svg_center}
            data-center-y={@svg_center}
            class="cursor-crosshair select-none"
          >
            <svg
              id="globe-viewport"
              width={@svg_size}
              height={@svg_size}
              viewBox={"0 0 #{@svg_size} #{@svg_size}"}
              class="rounded-full bg-white"
            >
              <circle
                id="globe-ocean-sphere"
                cx={@svg_center}
                cy={@svg_center}
                r={@session_state.radius}
                fill="#ffffff"
                stroke="#0f172a"
                stroke-width="2"
              />

              <g id="globe-graticule-layer">
                <%= for path_d <- @graticule_paths do %>
                  <path
                    d={path_d}
                    fill="none"
                    stroke="#cbd5e1"
                    stroke-width="0.85"
                    stroke-dasharray="3 3"
                  />
                <% end %>
              </g>

              <g id="globe-continents-layer">
                <%= for continent <- @continent_paths do %>
                  <path
                    id={"continent-#{String.downcase(String.replace(continent.name, " ", "-"))}"}
                    d={continent.path}
                    fill="#f8fafc"
                    stroke="#1e293b"
                    stroke-width="1.5"
                  />
                <% end %>
              </g>

              <g id="globe-expedition-arcs-layer">
                <%= for arc_d <- @arc_paths do %>
                  <path
                    d={arc_d}
                    fill="none"
                    stroke="#1d4ed8"
                    stroke-width="2.25"
                    stroke-linecap="round"
                  />
                <% end %>
              </g>

              <%= if @last_marker do %>
                <g id="globe-last-guess-markers">
                  <%= if @last_marker.guess_xy do %>
                    <circle
                      id="last-guess-pin"
                      cx={elem(@last_marker.guess_xy, 0)}
                      cy={elem(@last_marker.guess_xy, 1)}
                      r="5"
                      fill="#b91c1c"
                      stroke="#ffffff"
                      stroke-width="1.5"
                    />
                  <% end %>
                  <%= if @last_marker.target_xy do %>
                    <circle
                      id="last-target-pin"
                      cx={elem(@last_marker.target_xy, 0)}
                      cy={elem(@last_marker.target_xy, 1)}
                      r="6"
                      fill="#1d4ed8"
                      stroke="#ffffff"
                      stroke-width="1.5"
                    />
                  <% end %>
                </g>
              <% end %>
            </svg>
          </div>

          <script :type={Phoenix.LiveView.ColocatedHook} name=".GlobeDrag">
            export default {
              mounted() {
                this.dragging = false;
                this.moved = false;
                this.startX = 0;
                this.startY = 0;

                const svg = this.el.querySelector("svg");
                const centerX = parseFloat(this.el.dataset.centerX || "250");
                const centerY = parseFloat(this.el.dataset.centerY || "250");

                svg.addEventListener("pointerdown", (e) => {
                  this.dragging = true;
                  this.moved = false;
                  this.startX = e.clientX;
                  this.startY = e.clientY;
                });

                window.addEventListener("pointermove", (e) => {
                  if (!this.dragging) return;
                  const dx = e.clientX - this.startX;
                  const dy = e.clientY - this.startY;
                  if (Math.abs(dx) > 12 || Math.abs(dy) > 12) {
                    this.moved = true;
                    this.startX = e.clientX;
                    this.startY = e.clientY;
                    this.pushEvent("rotate_camera", {
                      dlat: (dy * 0.35).toFixed(2),
                      dlon: (-dx * 0.35).toFixed(2)
                    });
                  }
                });

                window.addEventListener("pointerup", () => {
                  this.dragging = false;
                });

                svg.addEventListener("click", (e) => {
                  if (this.moved) return;
                  const rect = svg.getBoundingClientRect();
                  const clickX = e.clientX - rect.left - centerX;
                  const clickY = e.clientY - rect.top - centerY;
                  this.pushEvent("globe_click", {
                    offset_x: clickX.toFixed(2),
                    offset_y: clickY.toFixed(2)
                  });
                });
              }
            }
          </script>
        </div>

        <div id="expedition-hud" class="lg:col-span-5 flex flex-col gap-5">
          <div class="rounded-xl border border-slate-200 bg-white p-5 shadow-xs">
            <div class="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h2 class="text-sm font-bold uppercase tracking-wider text-slate-800">
                  Expedition Status
                </h2>
                <p id="expedition-step-counter" class="text-xs text-slate-600">
                  Waypoint {min(@session_state.current_index + 1, length(@session_state.waypoints))} of {length(
                    @session_state.waypoints
                  )}
                </p>
              </div>
              <div class="text-right">
                <div id="expedition-total-score" class="text-lg font-bold text-blue-900">
                  {@session_state.total_score} pts
                </div>
                <div id="expedition-fuel-meter" class="text-xs font-medium text-slate-700">
                  Fuel: {@session_state.fuel}%
                </div>
              </div>
            </div>

            <%= if @current_waypoint && @session_state.status == :in_progress do %>
              <div id="active-clue-panel" class="mt-4 space-y-3">
                <div class="rounded-lg border border-slate-200 bg-slate-50 p-3">
                  <div class="text-xs font-semibold text-blue-900">
                    Active Clue (Tier {@session_state.clue_tier})
                  </div>
                  <p id="tier1-clue-text" class="mt-1 text-sm text-slate-900">
                    {@current_waypoint.tier1_clue}
                  </p>
                  <%= if @session_state.clue_tier >= 2 do %>
                    <p
                      id="tier2-clue-text"
                      class="mt-2 border-t border-slate-200 pt-2 text-xs text-slate-800"
                    >
                      {@current_waypoint.tier2_clue}
                    </p>
                  <% end %>
                  <%= if @session_state.clue_tier >= 3 do %>
                    <p
                      id="tier3-clue-text"
                      class="mt-2 border-t border-slate-200 pt-2 font-mono text-xs text-blue-900"
                    >
                      {@current_waypoint.tier3_clue}
                    </p>
                  <% end %>
                </div>

                <div class="flex items-center justify-between">
                  <.button
                    id="request-hint-btn"
                    phx-click="request_hint"
                    disabled={@session_state.clue_tier >= 3}
                  >
                    Unlock Next Clue Tier
                  </.button>
                  <.button id="reset-expedition-btn" phx-click="reset_expedition">
                    Reset Expedition
                  </.button>
                </div>
              </div>
            <% else %>
              <div
                id="expedition-complete-banner"
                class="mt-4 rounded-lg border border-blue-200 bg-blue-50 p-4"
              >
                <h3 class="text-sm font-bold text-blue-950">
                  Expedition {if(@session_state.status == :completed, do: "Completed", else: "Halted")}
                </h3>
                <p class="mt-1 text-xs text-blue-900">
                  Final Expedition Score: {@session_state.total_score} points
                </p>
                <div class="mt-3">
                  <.button id="restart-expedition-btn" phx-click="reset_expedition">
                    Start New Expedition
                  </.button>
                </div>
              </div>
            <% end %>
          </div>

          <div class="rounded-xl border border-slate-200 bg-white p-5 shadow-xs">
            <h3 class="text-xs font-bold uppercase tracking-wider text-slate-800 mb-3">
              Direct Coordinate Navigation (BISE Validated)
            </h3>
            <.form
              for={@coord_form}
              id="waypoint-guess-form"
              phx-submit="submit_guess"
              class="space-y-3"
            >
              <div class="grid grid-cols-2 gap-3">
                <.input
                  field={@coord_form[:lat]}
                  id="guess-lat-input"
                  label="Latitude (-90 to 90)"
                  type="text"
                />
                <.input
                  field={@coord_form[:lon]}
                  id="guess-lon-input"
                  label="Longitude (-180 to 180)"
                  type="text"
                />
              </div>
              <.button id="submit-guess-btn" type="submit" class="w-full">
                Plot Waypoint Coordinates
              </.button>
            </.form>
          </div>

          <div
            id="calibration-telemetry-card"
            class="rounded-xl border border-slate-200 bg-white p-5 shadow-xs"
          >
            <h3 class="text-xs font-bold uppercase tracking-wider text-slate-800">
              SkewPNN and A2 Calibration Telemetry
            </h3>
            <div class="mt-2 grid grid-cols-2 gap-2 text-xs text-slate-700">
              <div>
                Empirical Skewness:
                <span id="telemetry-gamma" class="font-mono font-semibold text-slate-900">{@session_state.skewness_gamma}</span>
              </div>
              <div>
                95% CI Mean:
                <span id="telemetry-ci-mean" class="font-mono font-semibold text-slate-900">{elem(
                  @ci_95,
                  0
                )}</span>
              </div>
              <div class="col-span-2">
                95% Confidence Bounds:
                <span id="telemetry-ci-bounds" class="font-mono text-slate-900">
                  [{elem(@ci_95, 1)}, {elem(@ci_95, 2)}]
                </span>
              </div>
            </div>
          </div>

          <div class="rounded-xl border border-slate-200 bg-white p-5 shadow-xs">
            <h3 class="text-xs font-bold uppercase tracking-wider text-slate-800 mb-2">
              Completed Expedition Legs
            </h3>
            <%= if @legs_empty? do %>
              <p id="expedition-log-empty" class="text-xs text-slate-500">
                Click on the orthographic globe or submit coordinates to record your first waypoint.
              </p>
            <% end %>
            <div id="expedition-log" phx-update="stream" class="space-y-2">
              <div
                :for={{id, leg} <- @streams.expedition_log}
                id={id}
                class="rounded-md border border-slate-200 bg-slate-50 p-2.5 text-xs text-slate-800"
              >
                <div class="flex items-center justify-between font-semibold text-slate-900">
                  <span>{leg.waypoint_name}</span>
                  <span>+{leg.points_awarded} pts</span>
                </div>
                <div class="mt-1 flex items-center justify-between text-slate-600">
                  <span>Residual: {leg.distance_km} km</span>
                  <span>Proficiency S_k: {leg.proficiency_score}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp assign_session_projection(socket, %SessionState{} = state) do
    center_pair = {@svg_center, @svg_center}
    graticules = Projection.graticule_paths(state.camera, state.radius, center_pair)

    continents =
      WorldData.continents()
      |> Enum.map(fn %{name: name, coords: coords} ->
        %{
          name: name,
          path: Projection.project_path(coords, state.camera, state.radius, center_pair)
        }
      end)
      |> Enum.reject(&(&1.path == ""))

    arc_paths =
      state.completed_legs
      |> Enum.map(fn leg ->
        Projection.project_path(leg.arc_coords, state.camera, state.radius, center_pair)
      end)
      |> Enum.reject(&(&1 == ""))

    last_marker =
      case state.last_guess do
        nil ->
          nil

        leg ->
          guess_xy =
            case Projection.forward(leg.guessed_coord, state.camera, state.radius) do
              {:ok, {gx, gy, _}} -> {@svg_center + gx, @svg_center + gy}
              :occluded -> nil
            end

          target_xy =
            case Projection.forward(leg.target_coord, state.camera, state.radius) do
              {:ok, {tx, ty, _}} -> {@svg_center + tx, @svg_center + ty}
              :occluded -> nil
            end

          %{guess_xy: guess_xy, target_xy: target_xy}
      end

    current_waypoint = Enum.at(state.waypoints, state.current_index)
    ci_95 = Calibration.confidence_interval_95(state.scores)

    socket
    |> assign(:session_state, state)
    |> assign(:current_waypoint, current_waypoint)
    |> assign(:graticule_paths, graticules)
    |> assign(:continent_paths, continents)
    |> assign(:arc_paths, arc_paths)
    |> assign(:last_marker, last_marker)
    |> assign(:ci_95, ci_95)
  end

  defp parse_float(val, _default) when is_float(val), do: val
  defp parse_float(val, _default) when is_integer(val), do: val * 1.0

  defp parse_float(val, default) when is_binary(val) do
    case Float.parse(String.trim(val)) do
      {num, _} -> num
      :error -> default
    end
  end

  defp parse_float(_, default), do: default

  defp generate_session_id do
    "exp-" <> Integer.to_string(:erlang.unique_integer([:positive]))
  end
end
