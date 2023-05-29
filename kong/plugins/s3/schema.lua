local typedefs = require "kong.db.schema.typedefs"
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

return {
  name = plugin_name,
  fields = {
    { protocols = typedefs.protocols_http },
    { config = {
      type = "record",
      fields = {
        { aws_key = {
          type = "string",
          encrypted = true, -- Kong Enterprise-exclusive feature, does nothing in Kong CE
          referenceable = true,
        } },
        { aws_secret = {
          type = "string",
          encrypted = true, -- Kong Enterprise-exclusive feature, does nothing in Kong CE
          referenceable = true,
        } },
        { aws_assume_role_arn = {
          type = "string",
          encrypted = true, -- Kong Enterprise-exclusive feature, does nothing in Kong CE
          referenceable = true,
        } },
        { aws_web_identity_credential = {
          type = "boolean",
          default = true,
        } },
        { aws_web_identity_token_file = {
          type = "string",
          required = false,
        } },
        { aws_web_identity_role_arn = {
          type = "string",
          required = false,
        } },
        { aws_role_session_name = {
          type = "string",
          default = "kong",
        } },
        { aws_region = typedefs.host },
        { aws_imds_protocol_version = {
          type = "string",
          required = true,
          default = "v1",
          one_of = { "v1", "v2" }
        } },
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
        {
          clear_query_string = {
            type = "boolean",
            default = false,
            required = true
          }
        },
      }
    },
  } },
  entity_checks = {
    { mutually_required = { "config.aws_key", "config.aws_secret" } },
  }
}
