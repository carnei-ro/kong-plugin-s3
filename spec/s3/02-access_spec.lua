require "spec.helpers"

local PLUGIN_NAME = "s3"

describe("[" .. PLUGIN_NAME .. "] access", function()

  local execute = require("kong.plugins." .. PLUGIN_NAME .. ".access").execute

  it("resquest to / should be to /index.html due to rewrites rules", function()
    local conf = {
      ["aws_key"]     = "my-key",
      ["aws_secret"]  = "my-secret",
      ["aws_region"]  = "us-east-1",
      ["bucket_name"] = "my-bucket",
      ["rewrites"] = {
        ["/"] = "/index.html"
      },
    }

    ngx.var = { upstream_uri = "/" }

    local req = execute(conf)
    assert.truthy(req)
    assert.equal(req.host, "s3." .. conf['aws_region'] .. ".amazonaws.com")
    assert.equal(req.path, ("/" .. conf.bucket_name .. conf['rewrites'][ngx.var.upstream_uri]) )
    assert.equal(req.port, 443)
    -- print(require('pl.pretty').write(req))
  end)

  it("resquest to /foo should be to /foo - not in rewrites rules", function()
    local conf = {
      ["aws_key"]     = "my-key",
      ["aws_secret"]  = "my-secret",
      ["aws_region"]  = "us-east-1",
      ["bucket_name"] = "my-bucket",
      ["rewrites"] = {
        ["/"] = "/index.html"
      },
    }

    ngx.var = { upstream_uri = "/foo" }

    local req = execute(conf)
    assert.truthy(req)
    assert.equal(req.host, "s3." .. conf['aws_region'] .. ".amazonaws.com")
    assert.equal(req.path, ("/" .. conf.bucket_name .. ngx.var.upstream_uri) )
    assert.equal(req.port, 443 )
    -- print(require('pl.pretty').write(req))
  end)

  it("s3 not in aws", function()
    local conf = {
      ["aws_key"]     = "my-key",
      ["aws_secret"]  = "my-secret",
      ["aws_region"]  = "us-east-1",
      ["bucket_name"] = "my-bucket",
      ["host"]        = "localstack-bucket.com",
      ["port"]        = 4566,
      ["rewrites"] = {
        ["/"] = "/index.html"
      },
    }

    ngx.var = { upstream_uri = "/my-bucket-key" }

    local req = execute(conf)
    assert.truthy(req)
    assert.equal(req.host, conf.host )
    assert.equal(req.path, ("/" .. conf.bucket_name .. ngx.var.upstream_uri) )
    assert.equal(req.port, conf.port )
    -- print(require('pl.pretty').write(req))
  end)

end)
