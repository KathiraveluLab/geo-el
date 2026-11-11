import Config

if System.get_env("PHX_SERVER") do
  config :geo_el, GeoElWeb.Endpoint, server: true
end

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host =
    System.get_env("PHX_HOST") ||
      System.get_env("RENDER_EXTERNAL_HOSTNAME") ||
      "localhost"

  port = String.to_integer(System.get_env("PORT") || "10000")

  config :geo_el, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  if score_path = System.get_env("SCORE_STORE_PATH") do
    config :geo_el, :score_store_path, score_path
  end

  if questions_path = System.get_env("QUESTIONS_PATH") do
    config :geo_el, :questions_path, questions_path
  end

  allowed_origins =
    if host == "localhost" do
      [
        "https://localhost",
        "http://localhost:#{port}",
        "http://127.0.0.1:#{port}"
      ]
    else
      [
        "https://#{host}",
        "//#{host}"
      ]
    end

  config :geo_el, GeoElWeb.Endpoint,
    server: true,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0},
      port: port
    ],
    check_origin: allowed_origins,
    secret_key_base: secret_key_base
end
