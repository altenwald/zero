import Config

config :zero_web, port: 4015

# Tests start a real server; keep it away from the port of a development instance.
if config_env() == :test do
  config :zero_web, port: 4115
  config :logger, level: :warning
end
