# Kong Plugin S3

summary: Get AWS S3 Objects with AWS V4 signed request

<!-- BEGINNING OF KONG-PLUGIN DOCS HOOK -->
## Plugin Priority

Priority: **750**

## Plugin Version

Version: **0.2.0**

## Configs

| name | type | required | default | validations |
| ---- | ---- | -------- | ------- | ----------- |
| config.aws_key | **string** | false |  |  |
| config.aws_secret | **string** | false |  |  |
| config.aws_region | **string** | true |  |  |
| config.bucket_name | **string** | true |  |  |
| config.rewrites | **map[string][string]** (*check `'config.rewrites' object`) | false | <pre>"/": "/index.html"</pre> |  |
| config.host | **string** | false |  |  |
| config.port | **integer** | false | <pre>443</pre> | <pre>- between:<br/>  - 0<br/>  - 65535</pre> |

### 'config.rewrites' object

| keys_type | keys_validations | values_type | values_required | values_default | values_validations |
| --------- | ---------------- | ----------- | --------------- | -------------- | ------------------ |
| **string** |  | **string** | true |  |  |

## Usage

```yaml
---
plugins:
- name: s3
  enabled: true
  config:
    aws_key: ''
    aws_secret: ''
    aws_region: ''
    bucket_name: ''
    rewrites: {}
    host: ''
    port: 443
```
<!-- END OF KONG-PLUGIN DOCS HOOK -->
