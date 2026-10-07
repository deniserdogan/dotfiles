local config = require("config.languages").server_config("yamlls")
config.settings.yaml.schemas = require("schemastore").yaml.schemas()
return config
