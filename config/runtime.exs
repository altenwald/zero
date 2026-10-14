import Config

# The port can be changed without rebuilding the release.
if port = System.get_env("PORT") do
  config :zero_web, port: String.to_integer(port)
end
