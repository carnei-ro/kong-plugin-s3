# Kong Plugin S3

summary: Get AWS S3 Objects with AWS V4 signed request

<!-- BEGINNING OF KONG-PLUGIN DOCS HOOK -->
## Plugin Priority

Priority: **750**

## Plugin Version

Version: **0.2.0**

## Config

| name | type | required | validations | default |
|-----|-----|-----|-----|-----|
| aws_key | string | <pre>false</pre> |  |  |
| aws_secret | string | <pre>false</pre> |  |  |
| aws_region | string | <pre>true</pre> |  |  |
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
      aws_region: ''
      bucket_name: ''
      rewrites:
        /: /index.html
      host: ''
      port: 443
      clear_query_string: false

```
<!-- END OF KONG-PLUGIN DOCS HOOK -->
