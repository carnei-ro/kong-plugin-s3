VERSION := $(shell sed -n "s/.*VERSION.*= \"\{1,\}\(.*\)\"/\1/p;"  kong/plugins/*/handler.lua | tr -d ',')
NAME := $(shell ls kong/plugins)
DIR_NAME=$(shell basename $${PWD})
UID := $(shell id -u)
GID := $(shell id -g)
SUMMARY := $(shell sed -n '/^summary: /s/^summary: //p' README.md)
export UID GID NAME VERSION

.DEFAULT_GOAL:=help

ifeq ($(origin DOCKER_COMPOSE_FILE),undefined)
DOCKER_COMPOSE_FILE := docker-compose-dbless.yaml
endif

ifeq ($(origin KONG_VERSION),undefined)
KONG_VERSION := 3.0.0
endif

help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: build
build: rockspec validate ## Build / Pack the plugin. Output at the ./dist directory
	@find kong/plugins/${NAME}/ -type f -iname "*lua~" -exec rm -f {} \;
	@docker run --rm -u 0 -v ${PWD}:/plugin \
		--entrypoint /bin/bash kong:3.0 \
		-c "cd /plugin ; apk add --no-cache zip; luarocks make > /dev/null 2>&1 ; luarocks pack kong-plugin-${NAME} 2> /dev/null ; chown ${UID}:${GID} *.rock"
	@mkdir -p dist
	@mv *.rock dist/
	@printf '\n\n Check "dist" folder \n\n'

.PHONY: validate
validate: ## Check plugin version, summary and create rockspec if not exists.
	@if [ -z "$${VERSION}" ]; then \
	  printf "\n\nNo VERSION found in handler.lua;\nPlease set it in your object that extends the base_plugin.\nEx: plugin.VERSION = \"0.1.0\"\n\n"; \
	  exit 1 ;\
	else \
	  echo ${VERSION} | egrep '^[0-9]\.[0-9]\.[0-9]$$' > /dev/null 2>&1 ; \
	  if [ $${?} -ne 0 ]; then \
  	    printf "\n\nVERSION must follow the Semantic Version pattern without additional labels for pre-releases.\nWhich means: Major.Minor.Patch, eg 0.1.0 or ...\nReceived: $${VERSION} \n\n"; \
	    exit 2 ; \
	  fi ; \
	fi
	@if [ -z "${SUMMARY}" ]; then \
  	  printf "\n\nNo SUMMARY found.\nPlease, create a 'README.md' file and place your summary there.\nFollow the pattern '^summary: '\nDo not use double quotes"; \
	  printf "\nExample:\nsummary: this is my summary\n\n\n" ;\
	  exit 4 ;\
	fi
	@if [ ! -f kong-plugin-${NAME}-${VERSION}-1.rockspec ]; then \
	  make rockspec; \
	fi

.PHONY: rockspec
rockspec: ## Create the RockSpec file, parsing the Plugin Name, Version, Dependencies and Summary.
	@printf 'package = "kong-plugin-%s"\nversion = "%s"\n\nsource = {\n url    = "%s",\n branch = "main"\n}\n\ndescription = {\n  summary = "%s",\n}\n\ndependencies = {\n' "${NAME}" "${VERSION}-1" "$(shell git remote -v | grep -E '^origin.*push.$$' | awk '{print $$2}')" "${SUMMARY}" > kong-plugin-${NAME}-${VERSION}-1.rockspec
	@grep -Ev '^#|^ *$$' dependencies.conf | sed -e 's/$$/",/g' -e 's/^/\ \ "/g' >> kong-plugin-${NAME}-${VERSION}-1.rockspec
	@printf '}\n\nbuild = {\n  type = "builtin",\n  modules = {\n' >> kong-plugin-${NAME}-${VERSION}-1.rockspec
	@find kong/plugins/${NAME} -type f -iname "*.lua" -exec bash -c 'printf "    [\"%s\"] = \"%s\",\n" "$$(tr '/' '.' <<< $${1/\.lua})" "{}"' _ {} \;	>> kong-plugin-${NAME}-${VERSION}-1.rockspec
	@printf "  }\n}\n" >> kong-plugin-${NAME}-${VERSION}-1.rockspec

.PHONY: clean
clean: ## Remove artifactory files and take down docker stack.
	@rm -rf *.rock *.rockspec dist shm kong/plugins/${NAME}/${NAME}
	@find kong/plugins/${NAME} -type f -iname "*lua~" -exec rm -f {} \;
	@docker-compose -f ${DOCKER_COMPOSE_FILE} down -v

.PHONY: clear
clear: clean ## Same as clean.

.PHONY: start
start: validate ## Exec start the docker-compose stack.
	@docker-compose -f ${DOCKER_COMPOSE_FILE} up -d

.PHONY: stop
stop: ## Stop the containers.
	@docker-compose -f ${DOCKER_COMPOSE_FILE} down

.PHONY: logs
logs: kong-logs ## Show Kong container logs.
.PHONY: kong-logs
kong-logs: ## Same as logs.
	@docker logs -f $$(docker ps -qf name=${DIR_NAME}-kong-1) 2>&1 || true

.PHONY: shell
shell: kong-bash ## Docker exec into Kong container shell.
.PHONY: kong-bash
kong-bash: ## Same as shell.
	@docker exec -it $$(docker ps -qf name=${DIR_NAME}-kong-1) bash || true

.PHONY: reload
reload: kong-reload ## Perform Kong Reload into Kong container.
.PHONY: kong-reload
kong-reload: ## Same as reload.
	@docker exec -it $$(docker ps -qf name=${DIR_NAME}-kong-1) bash -c "/usr/local/bin/kong reload"

.PHONY: restart
restart: ## Remove Kong container and recreate it.
	@docker rm -vf $$(docker ps -qf name=${DIR_NAME}-kong-1)
	@docker-compose -f ${DOCKER_COMPOSE_FILE} up -d

.PHONY: truncate-logs
truncate-logs: ## Needs sudo privileges: truncate Kong Container logs.
	@sudo truncate -s 0 $$(docker inspect --format='{{.LogPath}}' ${DIR_NAME}-kong-1)

.PHONY: reconfigure
reconfigure: clean start kong-logs ## Shortcut to clean, start, logs.

.PHONY: config-aux
config-aux: ## Works only with Database: Creates 'aux.lua' file and post it as a pre-function plugin to /aux route.
	@[ ! -f aux.lua ] && echo -e 'ngx.say("hello from aux - edit aux.lua and run make patch-aux")\nngx.exit(200)' > aux.lua || printf ''
	@curl -s -X POST http://localhost:8001/services/ -d 'name=aux' -d url=http://localhost
	@curl -s -X POST http://localhost:8001/services/aux/routes -d 'paths[]=/aux' -d 'name=aux'
	@curl -i -X POST http://localhost:8001/services/aux/plugins -F "name=pre-function" -F "config.functions=@aux.lua"

.PHONY: patch-aux
patch-aux: ## Works only with Database: Updates /aux pre-function plugin.
	@curl -i -X PATCH http://localhost:8001/plugins/$$(curl -s http://localhost:8001/plugins/ | jq -r ".data[] |  select (.name|test(\"pre-function\")) .id")      -F "name=pre-function"      -F "config.functions=@aux.lua"
	@echo " "

.PHONY: req-aux
req-aux: ## GET /aux endpoint.
	@curl -s http://localhost:8000/aux

.PHONY: resty-script
resty-script: ## Execute inside Kong Container the 'resty-script.lua' file.
	@docker exec -it $$(docker ps -qf name=${DIR_NAME}-kong-1) /usr/local/openresty/bin/resty /plugin-development/resty-script.lua || true

.PHONY: config
config: ## Works only with Database: Create a 'httpbin' service and '/' route. Add the custom-plugin to the '/' route.
	@curl -s -X POST http://localhost:8001/services/ -d 'name=httpbin' -d url=http://httpbin.org/anything
	@curl -s -X POST http://localhost:8001/services/httpbin/routes -d 'paths[]=/' -d 'name=root'
	@curl -i -X POST http://localhost:8001/routes/root/plugins -F "name=${NAME}"

.PHONY: config-plugin-remove
config-plugin-remove:  ## Works only with Database: Remove the custom-plugin.
	@curl -i -X DELETE http://localhost:8001/plugins/$$(curl -s http://localhost:8001/plugins/ | jq -r ".data[] |  select (.name|test(\"${NAME}\")) .id")

.PHONY: remove-all
remove-all: ## Works only with Database: Remove all configurations for plugins, consumers, routes, services, and upstreams
	@for i in plugins consumers routes services upstreams; do for j in $$(curl -s --url http://127.0.0.1:8001/$${i} | jq -r ".data[].id"); do curl -s -i -X DELETE --url http://127.0.0.1:8001/$${i}/$${j}; done; done

.PHONY: test
test: rockspec ## Execute 'pongo' tests with Kong Version 2.0.x.
	@sed 's/\(local PLUGIN_NAME\).*/\1 = "${NAME}"/g' -i spec/*/*.lua
	@KONG_VERSION=${KONG_VERSION} pongo run -v -o gtest ./spec

.PHONY: lint
lint: rockspec ## Execute 'pongo' lint
	@sed 's/\(local PLUGIN_NAME\).*/\1 = "${NAME}"/g' -i spec/*/*.lua
	@KONG_VERSION=${KONG_VERSION} pongo lint

.PHONY: update-readme
update-readme: ## Depends on Kong up and running: Updates 'Plugin Priority', 'Plugin Version', 'Configs' and 'Usage' sections from README.md file.
	@./update_readme.sh ${NAME} "http://${DIR_NAME}-kong-1:8001/schemas/plugins/" "http://${DIR_NAME}-kong-1:8001/"
