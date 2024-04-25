SHELL := /bin/bash
BUTANE := podman run --rm --interactive --security-opt label=disable --volume ${PWD}:/pwd --workdir /pwd quay.io/coreos/butane:release
SKOPEO := podman run --rm --interactive --network=host --volume ${PWD}:/pwd quay.io/skopeo/stable:latest
ASSETS_DIR := ignition-assets
TPL_DEP_SVC_FILES := $(shell find $(ASSETS_DIR) -type f -name '*.service.tpl')
DEP_SVC_FILES := $(TPL_DEP_SVC_FILES:%.service.tpl=%.service)
DEP_FILES := $(DEP_SVC_FILES) $(ASSETS_DIR)/registries.yaml
SERVER_BUTANE_FILES := $(shell echo *server.bu)
SERVER_IGNITION_FILES := $(SERVER_BUTANE_FILES:%.bu=%.ign)
AGENT_BUTANE_FILES := $(shell echo *node-*.bu)
AGENT_IGNITION_FILES := $(AGENT_BUTANE_FILES:%.bu=%.ign)
IGNITION_FILES := $(SERVER_IGNITION_FILES) $(AGENT_IGNITION_FILES)
CERTS_DIR := registry/certs
CA_SUBJECT := /C=AR/ST=Buenos Aires/L=La Plata/O=Mikrowaya/OU=DevOps/CN=CA
CERT_SUBJ_PREFIX ?= /C=AR/ST=Buenos Aires/L=La Plata/O=Mikrowaya/OU=DevOps/
REGISTRY_DNS := registry.$(REGISTRY_IP).nip.io
CERT_SUBJ := $(CERT_SUBJ_PREFIX)CN=$(REGISTRY_DNS)
CERT_ALTNAMES := [SAN]\nsubjectAltName=DNS:$(REGISTRY_DNS),IP:$(REGISTRY_IP)
REGISTRY_CONTAINER_NAME := k3s-poc-registry

.PHONY: all clean clean-agent .validate-envs certs load-local-registry agent

.validate-envs:
	@if [ -z "${REGISTRY_IP}" ]; then \
		echo >&2 "Must define REGISTRY_IP" && false; \
	fi

all: $(SERVER_IGNITION_FILES) $(DEP_SVC_FILES) $(CERTS_DIR)/cert.crt $(CERTS_DIR)/cert.key

$(ASSETS_DIR)/registries.yaml: $(ASSETS_DIR)/registries.yaml.tpl
	$(MAKE) .validate-envs
	sed "s/REGISTRY_HOST/${REGISTRY_DNS}/g" $< > $@

$(CERTS_DIR)/ca.crt $(CERTS_DIR)/ca.key:
	mkdir -p $(CERTS_DIR)
	@openssl req -x509 -new -nodes -keyout "$(CERTS_DIR)/ca.key" -sha256 \
		-days 3650 -out "$(CERTS_DIR)/ca.crt" -nodes -subj "$(CA_SUBJECT)"

$(CERTS_DIR)/cert.csr $(CERTS_DIR)/cert.key:
	$(MAKE) .validate-envs
	@openssl req -new -sha256 -nodes -subj "$(CERT_SUBJ)" -reqexts SAN \
		-config <(cat /etc/ssl/openssl.cnf <(printf "\n$(CERT_ALTNAMES)")) \
		-keyout "$(CERTS_DIR)/cert.key" -out "$(CERTS_DIR)/cert.csr"

$(CERTS_DIR)/cert.crt: $(CERTS_DIR)/cert.csr $(CERTS_DIR)/ca.key $(CERTS_DIR)/ca.crt
	@openssl x509 -req -in "$(CERTS_DIR)/cert.csr" -CA "$(CERTS_DIR)/ca.crt" \
		-CAkey "$(CERTS_DIR)/ca.key" -copy_extensions copyall -CAcreateserial \
		-out "$(CERTS_DIR)/cert.crt" -days 500 -sha256

$(ASSETS_DIR)/%.service: $(ASSETS_DIR)/%.service.tpl
	$(MAKE) .validate-envs
	sed "s/REGISTRY_HOST/${REGISTRY_DNS}/g" $< > $@

%-node-%.ign: %.bu $(DEP_FILES) $(CERTS_DIR)/ca.crt $(ASSETS_DIR)/agent.yaml
	@$(BUTANE) -d . $< > /dev/null
	@$(BUTANE) -d . $< > $@

%.ign: %.bu $(DEP_FILES) $(CERTS_DIR)/ca.crt
	@$(BUTANE) -d . $< > /dev/null
	@$(BUTANE) -d . $< > $@


certs: $(CERTS_DIR)/ca.crt $(CERTS_DIR)/cert.crt $(CERTS_DIR)/cert.key

tmp/k3s-airgap-images-amd64.tar.gz:
	mkdir -p tmp
	curl -Lo $@ \
		https://github.com/k3s-io/k3s/releases/download/v1.28.6%2Bk3s2/k3s-airgap-images-amd64.tar.gz

tmp/manifest.json: tmp/k3s-airgap-images-amd64.tar.gz
	tar -C tmp/ -zxf $< manifest.json

run-registry:
	$(MAKE) certs
	sudo podman container exists $(REGISTRY_CONTAINER_NAME) || \
	sudo podman run -d --name $(REGISTRY_CONTAINER_NAME) \
		-v `pwd`/$(CERTS_DIR):/certs -v registry:/var/lib/registry \
		-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/cert.crt \
		-e REGISTRY_HTTP_TLS_KEY=/certs/cert.key \
		-e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
		-p 443:443 \
		docker.io/library/registry:2

load-local-registry:
	$(MAKE) .validate-envs
	$(MAKE) tmp/manifest.json
	$(MAKE) run-registry
	for image in `cat tmp/manifest.json | jq -r '.[] | .RepoTags | join(",")'`; do \
		$(SKOPEO) copy --dest-tls-verify=false --all docker-archive:/pwd/tmp/k3s-airgap-images-amd64.tar.gz:$${image} docker://$(REGISTRY_DNS)/$${image}; \
	done
	$(SKOPEO) copy --dest-tls-verify=false --all \
		docker://ghcr.io/mikroways/fcos-k3s/server:latest \
		docker://$(REGISTRY_DNS)/mikroways/fcos-k3s/server:latest
	$(SKOPEO) copy --dest-tls-verify=false --all \
		docker://ghcr.io/mikroways/fcos-k3s/agent:latest \
		docker://$(REGISTRY_DNS)/mikroways/fcos-k3s/agent:latest


$(ASSETS_DIR)/agent.yaml: $(ASSETS_DIR)/agent.yaml.tpl
	@if [ -z "${K3S_API_SERVER_IP}" ]; then \
		echo >&2 "Must define K3S_API_SERVER_IP" && false; \
	fi
	@if [ -z "${K3S_API_SERVER_TOKEN}" ]; then \
		echo >&2 "Must define K3S_API_SERVER_TOKEN" && false; \
	fi
	sed "s/SERVER_IP/${K3S_API_SERVER_IP}/g;s/TOKEN/${K3S_API_SERVER_TOKEN}/g" $< > $@

agent: $(ASSETS_DIR)/agent.yaml $(AGENT_IGNITION_FILES)

clean-agent:
	rm -f $(ASSETS_DIR)/agent.yaml
	rm -f $(AGENT_IGNITION_FILES)
clean:
	$(MAKE) clean-agent
	rm -rf $(IGNITION_FILES) $(DEP_FILES) $(CERTS_DIR)
	@sudo podman container exists $(REGISTRY_CONTAINER_NAME) && \
		sudo podman rm --force $(REGISTRY_CONTAINER_NAME) || true
	@sudo podman volume rm registry
