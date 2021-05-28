local PLUGIN_NAME = "s3"

-- helper function to validate data against a schema
local validate do
  local validate_entity = require("spec.helpers").validate_plugin_config_schema
  local plugin_schema = require("kong.plugins."..PLUGIN_NAME..".schema")

  function validate(data)
    return validate_entity(data, plugin_schema)
  end
end


describe(PLUGIN_NAME .. ": (schema)", function()

  it("fail when passing only the aws key", function()
    local ok, err = validate({
        bucket_name = "mybucket",
        aws_region  = "us-east-1",
        aws_key     = "mykey",
      })
    assert.is_nil(ok)
    assert.is_truthy(err)
  end)

  it("fail when passing only the aws secret", function()
    local ok, err = validate({
        bucket_name = "mybucket",
        aws_region  = "us-east-1",
        aws_secret  = "mysecret",
      })
    assert.is_nil(ok)
    assert.is_truthy(err)
  end)

  it("ok when not pass aws key and secret", function()
    local ok, err = validate({
        bucket_name = "mybucket",
        aws_region  = "us-east-1",
        aws_key     = "mykey",
        aws_secret  = "mysecret",
      })
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)

  it("ok when not passing aws key and secret", function()
    local ok, err = validate({
        bucket_name = "mybucket",
        aws_region  = "us-east-1",
      })
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)

end)
