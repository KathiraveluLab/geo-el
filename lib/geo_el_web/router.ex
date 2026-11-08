defmodule GeoElWeb.Router do
  use GeoElWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GeoElWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", GeoElWeb do
    pipe_through :browser

    live "/", GlobeLive, :index
  end
end
