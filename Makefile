BINDIR ?= $(HOME)/.local/bin

# Builds the images with podman-compose and the image names from the
# compose files. `make base` builds the base images (compose/base.yml) one
# target at a time and in order, since each builds on the previous one; a
# plain `podman-compose build` starts them all at once, and each builds the
# shared stages again. Every other compose/TOOL.yml is a tool, with a service
# named TOOL, and gets a target named TOOL that builds the base images first.
# CT_USERNAME from the environment sets the main user's name, as in the
# compose files. JOBS is how many stages of one build run at once
# (podman build --jobs).
#
#   make images                    every image
#   make base                      the base images only
#   make pi                        the base images, then pi
#   make images BUILD_ARGS=--no-cache

# podman-compose 1.3.0 changes to the compose file's directory before
# opening it, so the path must be absolute. --podman-build-args is a
# global option and goes before the file.
JOBS = 8
COMPOSE = podman-compose --podman-build-args="--jobs $(JOBS)" -f
BUILD_ARGS =

BASE_TARGETS = base dev podman-in-podman
TOOLS := $(filter-out base,$(basename $(notdir $(wildcard compose/*.yml))))

.PHONY: install uninstall images base $(TOOLS)

install:
	mkdir -p $(BINDIR)
	ln -sfn $(CURDIR)/bin/ct $(BINDIR)/ct

uninstall:
	@if [ -L $(BINDIR)/ct ]; then rm $(BINDIR)/ct; echo "removed $(BINDIR)/ct"; fi

images: $(TOOLS)

base:
	for target in $(BASE_TARGETS); do \
		$(COMPOSE) $(CURDIR)/compose/base.yml build $(BUILD_ARGS) $$target || exit; \
	done

$(TOOLS): base
	$(COMPOSE) $(CURDIR)/compose/$@.yml build $(BUILD_ARGS) $@
