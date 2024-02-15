BUTANE := podman run --rm --interactive --security-opt label=disable --volume ${PWD}:/pwd --workdir /pwd quay.io/coreos/butane:release
DEP_FILES := $(shell find ignition-assets -type f)
BUTANE_FILES := $(shell echo *.bu)
IGNITION_FILES := $(BUTANE_FILES:%.bu=%.ign)

%.ign: %.bu $(DEP_FILES)
	@$(BUTANE) -d . $< > /dev/null
	@$(BUTANE) -d . $< > $@

all: $(IGNITION_FILES)

clean:
	rm -f $(IGNITION_FILES)

