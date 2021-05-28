local typedefs = require "kong.db.schema.typedefs"
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

local function keyring_enabled()
  local ok, enabled = pcall(function()
    return kong.configuration.keyring_enabled
  end)

  return ok and enabled or nil
end

-- symmetrically encrypt IAM access keys, if configured. this is available
-- in Kong Enterprise: https://docs.konghq.com/enterprise/1.3-x/db-encryption/
local ENCRYPTED = keyring_enabled()

return {
  name = plugin_name,
  fields = {
    { protocols = typedefs.protocols_http },
    { config = {
      type = "record",
      fields = {
        { aws_key = {
          type = "string",
          encrypted = ENCRYPTED,
        } },
        { aws_secret = {
          type = "string",
          encrypted = ENCRYPTED,
        } },
        { aws_region = typedefs.host { required = true } },
        { bucket_name = {
          type = "string",
          required = true,
        } },
        { rewrites = {
          type = "map",
          keys = {
            type = "string"
          },
          required = false,
          values = {
            type = "string",
            required = true,
          },
          default = {
            ['/'] = "/index.html",
          }
        } },
        { host = typedefs.host },
        { port = typedefs.port { default = 443 }, },
      }
    },
  } },
  entity_checks = {
    { mutually_required = { "config.aws_key", "config.aws_secret" } },
  }
}
