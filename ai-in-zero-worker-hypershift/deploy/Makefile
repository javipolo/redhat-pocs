l0-1:
	./tpl.sh l0/01-* | oc apply --context $(CONTEXT_L0) -f -

l0-2:
	./tpl.sh l0/02-* | oc apply --context $(CONTEXT_L0) -f -

l0-kubeconfigs:
	./genKubeConfig.sh assisted-service agentinstalladmission

clean-l0-kubeconfigs:
	-oc delete --context $(CONTEXT_L0) -n $(NAMESPACE_L0) secret managed-assisted-service-kubeconfig managed-agentinstalladmission-kubeconfig

clean-l0-1:
	-./tpl.sh l0/01-* | oc delete --context $(CONTEXT_L0) -f -

clean-l0-2:
	-./tpl.sh l0/02-* | oc delete --context $(CONTEXT_L0) -f -

l1-0:
	./tpl.sh l1/00-* | oc apply --context $(CONTEXT_L1) -f -

l1-1:
	./tpl.sh l1/01-* | oc apply --context $(CONTEXT_L1) -f -

l1-2:
	./tpl.sh l1/02-* | oc apply --context $(CONTEXT_L1) -f -

clean-l1-0:
	-./tpl.sh l1/00-* | oc delete --context $(CONTEXT_L1) -f -

clean-l1-1:
	-./tpl.sh l1/01-* | oc delete --context $(CONTEXT_L1) -f -

clean-l1-2:
	-./tpl.sh l1/02-* | oc delete --context $(CONTEXT_L1) -f -

clean: clean-l1-2 clean-l0-2 c clean-l1-1 clean-l0-1 clean-l0-kubeconfigs clean-l1-0
all: l1-0 l1-1 l0-kubeconfigs l0-1 l0-2 l1-2
