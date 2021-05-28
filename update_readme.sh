#!/bin/sh

cd $(git rev-parse --show-toplevel)

AUTO_PLUGIN_NAME=$(ls kong/plugins)

PLUGIN_NAME=${1:-$AUTO_PLUGIN_NAME}
KONG_SCHEMA_ENDPOINT=${2:-http://172.17.0.1:8001/schemas/plugins/}

# PLUGIN_PRIORITY=$(grep -ER 'PRIORITY( )*?=( )*?[0-9]+' 2>&1| grep handler.lua | grep -Eo '(PRIORITY.*[0-9]+)')

PLUGIN_PRIORITY=$(curl -s http://172.17.0.1:7999 | jq -r --arg NAME "${PLUGIN_NAME}" '.[] | select(.name==$NAME) .priority')
PLUGIN_VERSION=$(curl -s http://172.17.0.1:7999 | jq -r --arg NAME "${PLUGIN_NAME}" '.[] | select(.name==$NAME) .version')

BEGIN=$(nl -ba README.md | grep 'BEGINNING OF KONG-PLUGIN DOCS HOOK' | awk '{print $1}')
END=$(nl -ba README.md | grep 'END OF KONG-PLUGIN DOCS HOOK' | awk '{print $1}')

head -n${BEGIN} README.md > README-B
tail -n +${END} README.md > README-E

echo -e "## Plugin Priority\n\nPriority: **${PLUGIN_PRIORITY}**\n\n## Plugin Version\n\nVersion: **${PLUGIN_VERSION}**\n" >> README-B
docker run --rm leandrocarneiro/kong-plugin-schema-to-markdown:latest ${PLUGIN_NAME} ${KONG_SCHEMA_ENDPOINT} | sed "s/\r//g" >> README-B
cat README-B README-E > README.md
rm -f README-B README-E

cd - 2>&1 > /dev/null
