CONTAINER := podman
SHELL := /bin/bash
BUTANE := $(CONTAINER) run --rm --interactive --security-opt label=disable --volume ${PWD}:/pwd --workdir /pwd quay.io/coreos/butane:release
SKOPEO := $(CONTAINER) run --rm --interactive --network=host --volume ${PWD}:/pwd \
					-v ${HOME}/.local/share/containers/storage:/var/lib/containers/storage \
					quay.io/skopeo/stable:latest
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
ENCODED_SERVER_IGNITION_FILE := $(SERVER_IGNITION_FILES:%.ign=%.gzip.b64)

.PHONY: all clean clean-agent .validate-envs certs load-local-registry agent \
	load-server-image-local-registry load-agent-image-local-registry server

.validate-envs:
	@if [ -z "${REGISTRY_IP}" ]; then \
		echo >&2 "Must define REGISTRY_IP" && false; \
	fi

all: $(SERVER_IGNITION_FILES) $(DEP_SVC_FILES) $(CERTS_DIR)/cert.crt $(CERTS_DIR)/cert.key
	$(MAKE) load-server-image-local-registry
	$(MAKE) server

server: $(SERVER_IGNITION_FILES)
	@echo "# Select template VSPHERE_VM_TPL using (use full path): "
	@echo govc find -type m / -config.template true
	@echo export VSPHERE_VM_TPL=xxxx
	@echo
	@echo "# Set vm name using: "
	@echo export VSPHERE_VM_NAME=k3s-poc-server
	@echo
	@echo "# Clone vm from template:"
	@echo "# Needs VSPHERE_FOLDER and VSPHERE_DATASTORE to be set"
	@echo govc vm.clone -vm \$$VSPHERE_VM_TPL -on=false -folder \$$VSPHERE_FOLDER -ds \$$VSPHERE_DATASTORE \$$VM_NAME
	@echo
	@echo "# Encode ignition file:"
	@echo 'gzip -9c "$(SERVER_IGNITION_FILES)" | base64 -w0 - > "$(ENCODED_SERVER_IGNITION_FILE)"'
	@echo
	@echo "# Set ignition file for server"
	@echo govc vm.change -vm mw-poc-k3s -e "guestinfo.ignition.config.data.encoding=gzip+base64"
	@echo govc vm.change -vm mw-poc-k3s -f "guestinfo.ignition.config.data=${ENCODED_SERVER_IGNITION_FILE}"
	@echo
	@echo "# If needed fixed ip address"
	@echo "# See https://www.man7.org/linux/man-pages/man7/dracut.cmdline.7.html"
	@echo export IFACE='ens192'
	@echo export IPADD="192.168.22.42"
	@echo export IPMASK="255.255.255.0"
	@echo export IPGW="192.168.22.1"
	@echo export IPDNS1="8.8.8.8"
	@echo export IPDNS2="1.1.1.1"
	@echo export IPCFG="ip=\$${IPADD}::$${IPGW}:\$${IPMASK}:\$${VM_NAME}:\$${IFACE}:off:\$${IPDNS1}:\$${IPDNS2}"
	@echo govc vm.change -vm mw-poc-k3s -e "guestinfo.afterburn.initrd.network-kargs=\$${IPCFG}"

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

load-server-image-local-registry:
	$(MAKE) .validate-envs
	podman build --target server -f Containerfile  . -t k3s-custom-server
	$(SKOPEO) copy --dest-tls-verify=false --all \
		containers-storage:localhost/k3s-custom-server:latest \
		docker://$(REGISTRY_DNS)/mikroways/fcos-k3s/server:latest

load-agent-image-local-registry:
	$(MAKE) .validate-envs
	podman build --target agent -f Containerfile  . -t k3s-custom-agent
	$(SKOPEO) copy --dest-tls-verify=false --all \
		containers-storage:localhost/k3s-custom-agent:latest \
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
	$(MAKE) load-agent-image-local-registry

clean-agent:
	rm -f $(ASSETS_DIR)/agent.yaml
	rm -f $(AGENT_IGNITION_FILES)
clean:
	$(MAKE) clean-agent
	rm -rf $(IGNITION_FILES) $(DEP_FILES) $(CERTS_DIR)
	sudo podman container exists $(REGISTRY_CONTAINER_NAME) && \
		sudo podman rm --force $(REGISTRY_CONTAINER_NAME) || true
	sudo podman volume exists registry && sudo podman volume rm registry || true
