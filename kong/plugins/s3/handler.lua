local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")
local access = require("kong.plugins." .. plugin_name .. ".access")

local plugin = {
  PRIORITY = 750,
  VERSION = "0.3.0",
}

function plugin:access(plugin_conf)
  local req = access.execute(plugin_conf)
  kong.service.request.set_method(req.method)
  kong.service.request.set_scheme(req.scheme)
  kong.service.request.set_path(req.path)
  kong.service.set_target(req.host, req.port)
  kong.service.request.set_headers(req.headers)

  if plugin_conf.clear_query_string then
    kong.service.request.set_raw_query('')
  end
end

return plugin
