local kong        = kong
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")
local aws_v4      = require("kong.plugins." .. plugin_name .. ".v4")

local _M = {} --empty table to receive our functions

local IAM_CREDENTIALS_CACHE_KEY = "plugin." .. plugin_name .. ".iam_role_temp_creds"

local fetch_credentials
do
  local credential_sources = {
    require("kong.plugins." .. plugin_name .. ".iam-ecs-credentials"),
    -- The EC2 one will always return `configured == true`, so must be the last!
    require("kong.plugins." .. plugin_name .. ".iam-ec2-credentials"),
  }

  for _, credential_source in ipairs(credential_sources) do
    if credential_source.configured then
      fetch_credentials = credential_source.fetchCredentials
      break
    end
  end
end

local function patch_table_with_aws_credentials(conf, opts)
  -- Get AWS Access and Secret Key from conf or AWS Access, Secret Key and Token from cache or iam role
  if not conf.aws_key then
    -- no credentials provided, so try the IAM metadata service
    local iam_role_credentials = kong.cache:get(
      IAM_CREDENTIALS_CACHE_KEY,
      nil,
      fetch_credentials
    )

    if not iam_role_credentials then
      return kong.response.exit(500, {
        message = "Could not set access_key, secret_key and/or session_token"
      })
    end

    opts.access_key = iam_role_credentials.access_key
    opts.secret_key = iam_role_credentials.secret_key
    opts.headers["X-Amz-Security-Token"] = iam_role_credentials.session_token

  else
    opts.access_key = conf.aws_key
    opts.secret_key = conf.aws_secret
  end
end

function _M.execute(conf)
  local bucket_key = ((conf['rewrites'] ~= nil) and (conf['rewrites'][ngx.var.upstream_uri] ~= nil)) and conf['rewrites'][ngx.var.upstream_uri] or ngx.var.upstream_uri
  local bucket_name = conf.bucket_name

  local host = (conf['host'] ~= nil) and conf['host'] or (bucket_name .. '.s3.amazonaws.com')
  local port = (conf['port'] ~= nil) and conf['port'] or 443

  local opts = {
    region = conf.aws_region,
    service = 's3',
    method = 'GET',
    headers = {
      ["Accept"] = "application/json",
      ["x-amz-content-sha256"] = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" -- empty string hash https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html
    },
    path = '/' .. bucket_name .. bucket_key,
    host = host,
    port = port,
    query = nil,
    body = nil, 
  }

  patch_table_with_aws_credentials(conf, opts)
  local req, err = aws_v4(opts)
  if err then
    return kong.response.exit(400, err)
  end

  return {
    ['method']  = req.method,
    ['scheme']  = "https",
    ['path']    = req.target,
    ['host']    = (conf['host'] ~= nil) and conf['host'] or req.host,
    ['port']    = req.port,
    ['headers'] = req.headers,
  }
end

return _M
