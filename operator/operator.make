OPERATOR_SDK_VERSION=v1.0.0

# download operator-sdk binary
_work/bin/operator-sdk-$(OPERATOR_SDK_VERSION):
	mkdir -p _work/bin/ 2> /dev/null
	curl -L https://github.com/operator-framework/operator-sdk/releases/download/$(OPERATOR_SDK_VERSION)/operator-sdk-$(OPERATOR_SDK_VERSION)-x86_64-linux-gnu -o $(abspath $@)
	chmod a+x $(abspath $@)

# Re-generates the K8S source. This target is supposed to run
# upon any changes made to operator api.
#
# GOROOT is needed because of https://github.com/operator-framework/operator-sdk/issues/1854#issuecomment-525132306
operator-generate-k8s: _work/bin/operator-sdk-$(OPERATOR_SDK_VERSION)
	GOROOT=$(shell $(GO) env GOROOT) _work/bin/operator-sdk-$(OPERATOR_SDK_VERSION) generate k8s

# find or download if necessary controller-gen
# this make target is copied from Makefile generated
# by operator-sdk init
controller-gen:
ifeq (, $(shell which controller-gen))
	@{ \
	set -e; \
	CONTROLLER_GEN_TMP_DIR=$$(mktemp -d) ;\
	cd $$CONTROLLER_GEN_TMP_DIR ;\
	GOPATH=$$($(GO) env GOPATH) ;\
	$(GO) mod init tmp ;\
	$(GO) get sigs.k8s.io/controller-tools/cmd/controller-gen@v0.3.0 ;\
	rm -rf $$CONTROLLER_GEN_TMP_DIR; \
	}
CONTROLLER_GEN=$(GOPATH)/bin/controller-gen
else
CONTROLLER_GEN=$(shell which controller-gen)
endif

MANIFESTS_DIR=deploy/manifests
CATALOG_DIR=deploy/olm-catalog

operator-generate-crd: controller-gen
	@echo "Generating CRD ..."
	$(CONTROLLER_GEN) crd:trivialVersions=true,crdVersions=v1beta1 paths=./pkg/apis/... output:dir=$(MANIFESTS_DIR)/crd/
	@echo "resources: [pmem-csi.intel.com_deployments.yaml]" > $(MANIFESTS_DIR)/crd/kustomization.yaml

# Generate manifests. By default operator sdk adds ../{default,samples,scorecard}
# to kustomization.
# Add CRD, CR and operator deployment to kustomization
operator-generate-manifests: _work/bin/operator-sdk-$(OPERATOR_SDK_VERSION)
	@echo "Generating manifests ..."
	$< generate kustomize manifests --apis-dir ./pkg/apis/ --interactive=false --output-dir=$(MANIFESTS_DIR) && \
	$(MAKE) operator-generate-crd && \
	mkdir -p $(MANIFESTS_DIR)/default $(MANIFESTS_DIR)/samples && \
	echo -e "bases: [../crd, ../../kustomize/operator]\nimages:\n- name: intel/pmem-csi-driver\n  newTag: $(VERSION)" > $(MANIFESTS_DIR)/default/kustomization.yaml && \
	echo "resources: [../../common/pmem-csi.intel.com_v1alpha1_deployment_cr.yaml]" > $(MANIFESTS_DIR)/samples/kustomization.yaml && \
	sed -i -e 's;- ../scorecard;;g' -e 's;../;;g' $(MANIFESTS_DIR)/kustomization.yaml

# Generate packagemanifests with operator-sdk defaults.
operator-generate-catalog-base: _work/bin/operator-sdk-$(OPERATOR_SDK_VERSION) _work/kustomize operator-generate-manifests
	@echo "Generating base catalog ..."
	@_work/kustomize build --load_restrictor=none $(MANIFESTS_DIR) | $< generate packagemanifests --version $(VERSION) \
		--kustomize-dir $(MANIFESTS_DIR) --output-dir $(CATALOG_DIR)

# Extend/Patch base ClusterServiceVersion
operator-kustomize-catalog: _work/kustomize operator-generate-manifests operator-generate-catalog-base
	@echo "resources: [./$(VERSION)/pmem-csi-operator.clusterserviceversion.yaml]" > $(CATALOG_DIR)/kustomization.yaml
	@sed -i 's;X.Y.Z;$(VERSION);g' deploy/kustomize/olm-catalog/kustomization.yaml
	$< build --load_restrictor=none deploy/kustomize/olm-catalog -o deploy/olm-catalog/$(VERSION)/pmem-csi-operator.clusterserviceversion.yaml
	@sed -i 's;$(VERSION);X.Y.Z;g' deploy/kustomize/olm-catalog/kustomization.yaml
	@rm $(CATALOG_DIR)/kustomization.yaml

operator-generate-catalog: operator-kustomize-catalog
	$(MAKE) operator-clean-manifests

operator-clean-crd:
	rm -rf $(MANIFESTS_DIR)/crd

operator-clean-manifests:
	rm -rf $(MANIFESTS_DIR)

operator-clean-catalog:
	rm -rf $(CATALOG_DIR)
