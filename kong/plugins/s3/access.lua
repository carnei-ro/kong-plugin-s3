local plugin_name           = ({...})[1]:match("^kong%.plugins%.([^%.]+)")
local aws_v4                = require("kong.plugins." .. plugin_name .. ".v4")
local aws_ecs_cred_provider = require("kong.plugins." .. plugin_name .. ".iam-ecs-credentials")
local aws_ec2_cred_provider = require("kong.plugins." .. plugin_name .. ".iam-ec2-credentials")
local aws_sts_cred_source = require("kong.plugins." .. plugin_name .. ".iam-sts-credentials")

local ngx  = ngx
local kong = kong

local getenv = os.getenv

local _M = {}

local IAM_CREDENTIALS_CACHE_KEY_PATTERN = "plugin."..plugin_name..".iam_role_temp_creds.%s"
local AWS_PORT = 443
local AWS_REGION do
  AWS_REGION = getenv("AWS_REGION") or getenv("AWS_DEFAULT_REGION")
end
local AWS_ROLE_ARN do
  AWS_ROLE_ARN = os.getenv("AWS_ROLE_ARN")
end
local AWS_WEB_IDENTITY_TOKEN_FILE do
  AWS_WEB_IDENTITY_TOKEN_FILE = os.getenv("AWS_WEB_IDENTITY_TOKEN_FILE")
end
local fmt = string.format

local function fetch_aws_credentials(aws_conf)
  local fetch_metadata_credentials do
    local metadata_credentials_source = {
      aws_ecs_cred_provider,
      -- The EC2 one will always return `configured == true`, so must be the last!
      aws_ec2_cred_provider,
    }

    for _, credential_source in ipairs(metadata_credentials_source) do
      if credential_source.configured then
        fetch_metadata_credentials = credential_source.fetchCredentials
        break
      end
    end
  end

  if aws_conf.aws_assume_role_arn then
    local metadata_credentials, err

    if aws_conf.aws_web_identity_credential then
      local err_wic
      metadata_credentials, err_wic = aws_sts_cred_source.fetchCredentials(aws_conf)
      if err_wic then
        kong.log.err(err_wic, " falling back to fetch_metadata_credentials")
      end
    end

    if (metadata_credentials == nil) or (not metadata_credentials.access_key) then
      metadata_credentials, err = fetch_metadata_credentials(aws_conf)
    end

    if err then
      return nil, err
    end

    return aws_sts_cred_source.fetch_assume_role_credentials(aws_conf.aws_region,
                                                             aws_conf.aws_assume_role_arn,
                                                             aws_conf.aws_role_session_name,
                                                             metadata_credentials.access_key,
                                                             metadata_credentials.secret_key,
                                                             metadata_credentials.session_token)

  else
    if not aws_conf.aws_web_identity_credential then
      return fetch_metadata_credentials(aws_conf)
    end

    local credentials, err
    credentials, err = aws_sts_cred_source.fetchCredentials(aws_conf)
    if err then
      kong.log.err(err, " falling back to fetch_metadata_credentials")
      return fetch_metadata_credentials(aws_conf)
    end
    return credentials
  end
end

local function patch_table_with_aws_credentials(conf, opts)
  -- Get AWS Access and Secret Key from conf or AWS Access, Secret Key and Token from cache or iam role
  if not conf.aws_key then
    -- no credentials provided, so try the IAM metadata service
    local iam_role_cred_cache_key = fmt(IAM_CREDENTIALS_CACHE_KEY_PATTERN, conf.aws_assume_role_arn or "default")
    local iam_role_credentials = kong.cache:get(
      iam_role_cred_cache_key,
      nil,
      fetch_aws_credentials,
      conf
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
  if not bucket_key then
    bucket_key = ((conf['rewrites'] ~= nil) and (conf['rewrites'][ngx.var.request_uri] ~= nil)) and conf['rewrites'][ngx.var.request_uri] or ngx.var.request_uri
  end
  if not bucket_key then
    kong.log.err("bucket_key is nil")
    bucket_key = '/index.html'
  end

  local bucket_name = conf.bucket_name

  conf.aws_web_identity_token_file = conf.aws_web_identity_token_file and conf.aws_web_identity_token_file or AWS_WEB_IDENTITY_TOKEN_FILE
  conf.aws_web_identity_role_arn = conf.aws_web_identity_role_arn and conf.aws_web_identity_role_arn or AWS_ROLE_ARN

  local region = conf.aws_region or AWS_REGION

  local host = (conf['host'] ~= nil) and conf['host'] or (fmt("s3.%s.amazonaws.com", region))
  local port = (conf['port'] ~= nil) and conf['port'] or AWS_PORT

  local opts = {
    region = region,
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
