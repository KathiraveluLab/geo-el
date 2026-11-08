import Config

config :geo_el, GeoElWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_for_geo_el_spherical_adventure_engine_64_bytes_minimum",
  server: false

config :geo_el,
  score_store_path: Path.expand("../_build/test/leaderboard_test.json", __DIR__)

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
