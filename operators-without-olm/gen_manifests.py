#!/usr/bin/env python

# This script is used to generate kubernetes resource list like OLM based
# upon the CSV and static resources in the manifestdir
# usage:
#   ./gen_manifests.py <manifest_dir> [namespace]
#
#   i.e. ./gen_manifests.py bundle/manifests/clusterlogging.clusterserviceversion.yaml | oc create -f -

# This script is a copy slightly modified of
# https://github.com/openshift/cluster-logging-operator/blob/master/hack/gen-olm-artifacts.py

import os
import sys
import yaml

csv_file = sys.argv[1]
csv_dir = os.path.dirname(csv_file)
kinds = "ns,sa,role,clusterrole,dep"
namespace = None
if len(sys.argv) == 3:
    namespace = sys.argv[2]


def grepx(file, pattern):
    with open(file) as f:
        datafile = f.readlines()
    for line in datafile:
        if line.strip() == pattern:
            return True
    return False


def load_file(file):
    with open(file, "r") as stream:
        try:
            return yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)


def write_resource(resource):
    sys.stdout.write("---\n")
    yaml.dump(resource, sys.stdout, default_flow_style=False)


def get_namespace(csv):
    if "operatorframework.io/suggested-namespace" in csv["metadata"]:
        return csv["metadata"]["operatorframework.io/suggested-namespace"]
    return csv["metadata"]["name"].split(".")[0]


def generate_namespace(namespace):
    ns = {
        "apiVersion": "v1",
        "kind": "Namespace",
        "metadata": {
            "name": namespace,
            "annotations": {"openshift.io/node-selector": ""},
        },
        "labels": {
            "openshift.io/cluster-logging": "true",
            "openshift.io/cluster-monitoring": "true",
        },
    }
    write_resource(ns)


def generate_deployments(csv):
    for d in csv["spec"]["install"]["spec"]["deployments"]:
        deployment = {
            "apiVersion": "apps/v1",
            "kind": "Deployment",
            "metadata": {"name": d["name"], "namespace": namespace},
            "spec": d["spec"],
        }
        deployment["spec"]["template"]["metadata"]["annotations"] = {
            "olm.targetNamespaces": namespace
        }
        deployment["spec"]["template"]["spec"]["containers"][0][
            "imagePullPolicy"
        ] = "Always"
        write_resource(deployment)


def generate_serviceaccounts(csv, namespace):
    sas = set()
    if "permissions" in csv["spec"]["install"]["spec"]:
        for p in csv["spec"]["install"]["spec"]["permissions"]:
            sas.add(p["serviceAccountName"])
    for p in csv["spec"]["install"]["spec"]["clusterPermissions"]:
        sas.add(p["serviceAccountName"])
    for sa in sas:
        serviceaccount = {
            "apiVersion": "v1",
            "kind": "ServiceAccount",
            "metadata": {
                "name": sa,
                "namespace": namespace,
            },
        }
        write_resource(serviceaccount)


def generate_cluster_permissions(csv, namespace):
    for perm in csv["spec"]["install"]["spec"]["clusterPermissions"]:
        name = perm["serviceAccountName"]
        clusterrole = {
            "apiVersion": "rbac.authorization.k8s.io/v1",
            "kind": "ClusterRole",
            "metadata": {"name": name},
            "rules": perm["rules"],
        }
        write_resource(clusterrole)
        binding = {
            "apiVersion": "rbac.authorization.k8s.io/v1",
            "kind": "ClusterRoleBinding",
            "metadata": {"name": name},
            "roleRef": {
                "apiGroup": "rbac.authorization.k8s.io",
                "kind": "ClusterRole",
                "name": name,
            },
            "subjects": [
                {"kind": "ServiceAccount", "name": name, "namespace": namespace}
            ],
        }
        write_resource(binding)


def generate_permissions(csv):
    if "permissions" in csv["spec"]["install"]["spec"]:
        for perm in csv["spec"]["install"]["spec"]["permissions"]:
            name = perm["serviceAccountName"]
            role = {
                "apiVersion": "rbac.authorization.k8s.io/v1",
                "kind": "Role",
                "metadata": {"name": name, "namespace": namespace},
                "rules": perm["rules"],
            }
            write_resource(role)
            binding = {
                "apiVersion": "rbac.authorization.k8s.io/v1",
                "kind": "RoleBinding",
                "metadata": {"name": name, "namespace": namespace},
                "roleRef": {
                    "apiGroup": "rbac.authorization.k8s.io",
                    "kind": "Role",
                    "name": name,
                },
                "subjects": [{"kind": "ServiceAccount", "name": name}],
            }
            write_resource(binding)


def generate_crds(csv):
    for crdDef in csv["spec"]["customresourcedefinitions"]["owned"]:
        name = crdDef["name"]
        segments = name.split(".")
        crd = {
            "apiVersion": "apiextensions.k8s.io/v1",
            "kind": "CustomResourceDefinition",
            "metadata": {"name": name},
            "spec": {
                "group": ".".join(segments[1:]),
                "names": {
                    "kind": crdDef["kind"],
                    "listKind": crdDef["kind"] + "List",
                    "plural": segments[0],
                    "singular": crdDef["kind"].lower(),
                },
                "scope": "Namespaced",
                "version": crdDef["version"],
            },
        }
        write_resource(crd)


csv = load_file(csv_file)
"""
01-namespace
02-sa
03-role
04-rolebinding
05-crd
06-deployment
"""

if not namespace:
    namespace = get_namespace(csv)

static_files = [
    f
    for f in os.listdir(csv_dir)
    if not grepx(os.path.join(csv_dir, f), "kind: ClusterServiceVersion")
]
static_files.sort()

for f in static_files:
    static_yaml = load_file(os.path.join(csv_dir, f))
    write_resource(static_yaml)

for kind in kinds.split(","):
    if kind == "ns":
        generate_namespace(namespace)
    elif kind == "sa":
        generate_serviceaccounts(csv, namespace)
    elif kind == "clusterrole":
        generate_cluster_permissions(csv, namespace)
    elif kind == "role":
        generate_permissions(csv)
    elif kind == "dep":
        generate_deployments(csv)
    elif kind == "crd":
        generate_crds(csv)
