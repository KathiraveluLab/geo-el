defmodule GeoElWeb.CoreComponents do
  @moduledoc """
  Provides core UI components styled for a high-contrast light theme.
  """

  use Phoenix.Component

  alias Phoenix.HTML.Form

  attr :name, :string, required: true
  attr :class, :string, default: "w-5 h-5"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  attr :type, :string, default: "button"
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex items-center justify-center rounded-md border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-900 shadow-xs transition hover:bg-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-700",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :type, :string, default: "text"
  attr :field, Phoenix.HTML.FormField, doc: "a form field struct retrieved from the form"
  attr :errors, :list, default: []
  attr :class, :string, default: nil

  attr :rest, :global,
    include: ~w(autocomplete disabled max min pattern placeholder readonly required step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error/1))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(assigns) do
    ~H"""
    <div>
      <%= if @label do %>
        <label for={@id} class="block text-xs font-semibold text-slate-800 mb-1">
          {@label}
        </label>
      <% end %>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Form.normalize_value(@type, @value)}
        class={
          @class ||
            "block w-full rounded-md border border-slate-300 bg-white px-2.5 py-1.5 text-sm text-slate-900 shadow-2xs focus:border-blue-700 focus:outline-none focus:ring-1 focus:ring-blue-700"
        }
        {@rest}
      />
      <%= for msg <- @errors do %>
        <p class="mt-1 text-xs text-red-700">{msg}</p>
      <% end %>
    </div>
    """
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
