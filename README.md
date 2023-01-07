# Kong Plugin S3

summary: Get AWS S3 Objects with AWS V4 signed request

<!-- BEGINNING OF KONG-PLUGIN DOCS HOOK -->
## Plugin Priority

Priority: **750**

## Plugin Version

Version: **0.3.0**

## Config

&ast; This field is _referenceable_, which means it can be securely stored as a [secret](https://docs.konghq.com/gateway/latest/kong-enterprise/secrets-management/) in a vault. References must follow a [specific format](https://docs.konghq.com/gateway/latest/kong-enterprise/secrets-management/reference-format/).

| name | type | required | validations | default |
|-----|-----|-----|-----|-----|
| aws_key* | string | <pre>false</pre> |  |  |
| aws_secret* | string | <pre>false</pre> |  |  |
| aws_assume_role_arn* | string | <pre>false</pre> |  |  |
| aws_role_session_name | string | <pre>false</pre> |  | <pre>kong</pre> |
| aws_region | string | <pre>false</pre> |  |  |
| aws_imds_protocol_version | string | <pre>true</pre> | <pre>- one_of:<br/>  - v1<br/>  - v2</pre> | <pre>v1</pre> |
| bucket_name | string | <pre>true</pre> |  |  |
| rewrites | map[string][string] | <pre>false</pre> |  | <pre>/: /index.html</pre> |
| host | string | <pre>false</pre> |  |  |
| port | integer | <pre>false</pre> | <pre>- between:<br/>  - 0<br/>  - 65535</pre> | <pre>443</pre> |
| clear_query_string | boolean | <pre>true</pre> |  | <pre>false</pre> |

## Usage

```yaml
plugins:
  - name: s3
    enabled: true
    config:
      aws_key: ''
      aws_secret: ''
      aws_assume_role_arn: ''
      aws_role_session_name: kong
      aws_region: ''
      aws_imds_protocol_version: v1
      bucket_name: ''
      rewrites:
        /: /index.html
      host: ''
      port: 443
      clear_query_string: false

```
<!-- END OF KONG-PLUGIN DOCS HOOK -->
