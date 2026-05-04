PWD := $(shell pwd)

# Determine if "docker" is actually podman
DOCKER_VERSION_OUTPUT := $(shell docker --version 2>&1)
PODMAN_REFERENCES := $(shell echo $(DOCKER_VERSION_OUTPUT) | grep -ic podman)

ifneq ($(strip $(DOCKER_VERSION_OUTPUT)),)
ifeq ($(PODMAN_REFERENCES),0)
    DOCKER_COMMAND := docker
endif
endif

ifndef DOCKER_COMMAND
    ifneq ($(strip $(shell podman --version 2>&1)),)
        DOCKER_COMMAND := podman
    endif
endif

ifndef DOCKER_COMMAND
    $(info Neither docker nor podman can be executed. Did you install and configure one of them to be used?)
endif

DOCKER_RUN=$(DOCKER_COMMAND) run
DOCKER_USER=$(shell id -u):$(shell id -g)
DOCKER_USER_IS_HOST_USER_ARG=-u $(DOCKER_USER)
ifeq ($(DOCKER_COMMAND),podman)
    DOCKER_USER_IS_HOST_USER_ARG=--userns=keep-id -u $(DOCKER_USER)
endif

# Parse weaver container from dependencies.Dockerfile
WEAVER_CONTAINER=$(shell awk '/^FROM/ {print $$2}' dependencies.Dockerfile)

.PHONY: table-generation registry-generation fix check clean

# Generate markdown tables from YAML definitions
table-generation:
	$(DOCKER_RUN) --rm \
		$(DOCKER_USER_IS_HOST_USER_ARG) \
		--mount 'type=bind,source=$(PWD)/templates,target=/home/weaver/templates,readonly' \
		--mount 'type=bind,source=$(PWD)/model,target=/home/weaver/source,readonly' \
		--mount 'type=bind,source=$(PWD)/docs-src,target=/home/weaver/target' \
		$(WEAVER_CONTAINER) registry update-markdown \
		--registry=/home/weaver/source \
		--param registry_base_url=/docs-src/registry/ \
		--templates=/home/weaver/templates \
		--target=markdown \
		--future \
		/home/weaver/target

# Generate registry markdown (attributes, etc.).
registry-generation:
	$(DOCKER_RUN) --rm \
		$(DOCKER_USER_IS_HOST_USER_ARG) \
		--mount 'type=bind,source=$(PWD)/templates,target=/home/weaver/templates,readonly' \
		--mount 'type=bind,source=$(PWD)/model,target=/home/weaver/source,readonly' \
		--mount 'type=bind,source=$(PWD)/docs-src,target=/home/weaver/target' \
		$(WEAVER_CONTAINER) registry generate \
		  --registry=/home/weaver/source \
		  --templates=/home/weaver/templates \
		  markdown \
		  /home/weaver/target/registry/

# Run both table-generation and registry-generation
fix: table-generation registry-generation
	@echo "All autofixes complete"

# Check: run registry generation and validate that docs are up to date
check: registry-generation
	@git diff --exit-code 'docs-src/registry/*.md' || (echo "Run make fix and commit." && exit 1)

# Clean generated artifacts
clean:
	rm -rf docs-src/registry docs-src/

.DEFAULT_GOAL := check
