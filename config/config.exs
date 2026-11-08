import Config

config :geo_el,
  generators: [timestamp_type: :utc_datetime]

config :geo_el, GeoElWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: GeoElWeb.ErrorHTML, json: GeoElWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: GeoEl.PubSub,
  live_view: [signing_salt: "geo_el_live_view_salt"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
