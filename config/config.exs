import Config

config :etag_plug,
  generator: ETag.Generator.SHA1,
  methods: ["GET"],
  status_codes: [200]

config :zero_web, port: 4015
