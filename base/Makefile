# Builds the base images from Containerfile, one target at a time and in
# order, with the image names from ../compose/base.yml. Each target depends
# on the previous one, so `make -j` keeps the order too. CT_USERNAME from
# the environment sets the main user's name, as in the compose files.
#
#   make -C base                   all three images
#   make -C base dev               base and dev only
#   make -C base BUILD_ARGS=--no-cache

COMPOSE = podman-compose -f ../compose/base.yml
BUILD_ARGS =

.PHONY: all base dev podman-in-podman

all: podman-in-podman

base:
	$(COMPOSE) build $(BUILD_ARGS) base

dev: base
	$(COMPOSE) build $(BUILD_ARGS) dev

podman-in-podman: dev
	$(COMPOSE) build $(BUILD_ARGS) podman-in-podman
