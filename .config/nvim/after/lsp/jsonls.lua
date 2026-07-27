local config = require("config.languages").server_config("jsonls")
config.settings.json.schemas = require("schemastore").json.schemas()
return config
