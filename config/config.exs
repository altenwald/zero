use Mix.Config

config :etag_plug,
  generator: ETag.Generator.SHA1,
  methods: ["GET"],
  status_codes: [200]

config :mine, port: 4015
