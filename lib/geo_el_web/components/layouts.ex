defmodule GeoElWeb.Layouts do
  @moduledoc """
  Application layouts rendered in a high-contrast light theme for cartographic clarity.
  """

  use GeoElWeb, :html

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-slate-900">
      <header class="border-b border-slate-200 bg-slate-50 px-6 py-3">
        <div class="mx-auto flex max-w-7xl items-center justify-between">
          <div class="flex items-center gap-2">
            <.icon name="hero-globe-alt" class="w-6 h-6 text-blue-800" />
            <span class="text-lg font-bold tracking-tight text-slate-900">Geo-El</span>
            <span class="text-xs font-medium text-slate-600">
              Spherical Geodesic Adventure Engine
            </span>
          </div>
          <div class="text-xs font-medium text-slate-700">
            Orthographic LiveView Telemetry
          </div>
        </div>
      </header>

      <main class="mx-auto max-w-7xl px-6 py-6">
        <.flash_group flash={@flash} />
        {render_slot(@inner_block)}
      </main>
    </div>
    """
  end

  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div id="flash-group" class="mb-4 space-y-2">
      <%= if info = Phoenix.Flash.get(@flash, :info) do %>
        <div
          id="flash-info"
          class="rounded-md border border-blue-300 bg-blue-50 px-4 py-2 text-sm text-blue-900"
        >
          {info}
        </div>
      <% end %>
      <%= if error = Phoenix.Flash.get(@flash, :error) do %>
        <div
          id="flash-error"
          class="rounded-md border border-red-300 bg-red-50 px-4 py-2 text-sm text-red-900"
        >
          {error}
        </div>
      <% end %>
    </div>
    """
  end
end

