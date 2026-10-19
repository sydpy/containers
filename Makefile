BINDIR ?= $(HOME)/.local/bin

.PHONY: install uninstall

install:
	mkdir -p $(BINDIR)
	ln -sfn $(CURDIR)/bin/ct $(BINDIR)/ct

uninstall:
	@if [ -L $(BINDIR)/ct ]; then rm $(BINDIR)/ct; echo "removed $(BINDIR)/ct"; fi
