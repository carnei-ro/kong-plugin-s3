#!/bin/sh

cd $(git rev-parse --show-toplevel)

AUTO_PLUGIN_NAME=$(ls kong/plugins)

PLUGIN_NAME=${1:-$AUTO_PLUGIN_NAME}
KONG_SCHEMA_ENDPOINT=${2:-http://127.0.0.1:8001/schemas/plugins/}
KONG_PLUGIN_METADATA_ENDPOINT=${3:-http://127.0.0.1:8001/}

BEGIN=$(nl -ba README.md | grep 'BEGINNING OF KONG-PLUGIN DOCS HOOK' | awk '{print $1}')
END=$(nl -ba README.md | grep 'END OF KONG-PLUGIN DOCS HOOK' | awk '{print $1}')

head -n${BEGIN} README.md > README-B
tail -n +${END} README.md > README-E

docker run --network=$(basename ${PWD})_default --rm leandrocarneiro/kong-plugin-schema-to-markdown:3.0 ${PLUGIN_NAME} ${KONG_SCHEMA_ENDPOINT} ${KONG_PLUGIN_METADATA_ENDPOINT} | sed "s/\r//g" >> README-B

cat README-B README-E > README.md
rm -f README-B README-E

cd - 2>&1 > /dev/null
