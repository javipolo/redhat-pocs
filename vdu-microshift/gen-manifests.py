#!/usr/bin/env python

# This script is used to generate kubernetes resource list like OLM based
# upon the CSV and static resources in the manifestdir
# usage:
#   ./hack/gen-manifests.py <manifest_dir> [namespace]
#
#   i.e. ./hack/gen-manifests.py bundle/manifests/clusterlogging.clusterserviceversion.yaml | oc create -f -

# Original script
# https://github.com/openshift/cluster-logging-operator/blob/master/hack/gen-olm-artifacts.py

import  os, sys, yaml, re

csvFile = sys.argv[1]
csvDir =  os.path.dirname(csvFile)
kinds = "ns,sa,role,clusterrole,dep"
namespace = None
if len(sys.argv) == 3:
  namespace = sys.argv[2]

def loadFile(file):
  with open(file, "r") as stream:
    try:
      return yaml.safe_load(stream)
    except yaml.YAMLError as exc:
      print(exc)

def writeResource(resource):
  sys.stdout.write("---\n")
  yaml.dump(resource, sys.stdout, default_flow_style=False)

def getNamespace(csv):
  if 'operatorframework.io/suggested-namespace' in csv['metadata']:
    return csv['metadata']['operatorframework.io/suggested-namespace']
  return csv['metadata']['name'].split(".")[0]

def generateNamespace(namespace):
  ns = {
    "apiVersion": "v1",
    "kind": "Namespace",
    "metadata": {
      "name": namespace,
      "annotations": {
        "openshift.io/node-selector": ""
      }
    },
    "labels": {
      "openshift.io/cluster-logging": "true",
      "openshift.io/cluster-monitoring": "true"
    }
  }
  writeResource(ns)

def generateDeployments(csv):
  for d in csv['spec']['install']['spec']['deployments']:
      deployment = {
        "apiVersion": "apps/v1",
        "kind" : "Deployment",
        "metadata" : {
          "name" : d['name'],
          "namespace": namespace
        },
        "spec" : d['spec']
      }
      deployment['spec']['template']['metadata']['annotations'] = {
            "olm.targetNamespaces" : namespace
      }
      deployment['spec']['template']['spec']['containers'][0]['imagePullPolicy'] = 'Always'
      environ = deployment['spec']['template']['spec']['containers'][0]['env']
      writeResource(deployment)

def generateServiceAccounts(csv, namespace):
  sas = set()
  if 'permissions' in csv['spec']['install']['spec']:
    for p in csv['spec']['install']['spec']['permissions']:
        sas.add(p['serviceAccountName'])
  for p in csv['spec']['install']['spec']['clusterPermissions']:
      sas.add(p['serviceAccountName'])
  for sa in sas:
      serviceaccount = {
        "apiVersion": "v1",
        "kind" : "ServiceAccount",
        "metadata" : {
          "name" : sa,
          "namespace" : namespace,
        }
      }
      writeResource(serviceaccount)

def generateClusterPermissions(csv, namespace):
  for perm in csv['spec']['install']['spec']['clusterPermissions']:
      name = perm['serviceAccountName']
      clusterrole = {
        "apiVersion": "rbac.authorization.k8s.io/v1",
        "kind" : "ClusterRole",
        "metadata" : {
          "name" : name
        },
        "rules" : perm['rules']
      }
      writeResource(clusterrole)
      binding = {
        "apiVersion": "rbac.authorization.k8s.io/v1",
        "kind" : "ClusterRoleBinding",
        "metadata" : {
          "name" : name
        },
        "roleRef" : {
           "apiGroup" : "rbac.authorization.k8s.io",
           "kind" : "ClusterRole",
           "name" : name
        },
        "subjects" : [
          {
            "kind":"ServiceAccount",
            "name": name,
            "namespace": namespace
          }
        ]
      }
      writeResource(binding)

def generatePermissions(csv):
  if 'permissions' in csv['spec']['install']['spec']:
    for perm in csv['spec']['install']['spec']['permissions']:
        name = perm['serviceAccountName']
        role = {
          "apiVersion": "rbac.authorization.k8s.io/v1",
          "kind" : "Role",
          "metadata" : {
            "name" : name,
            "namespace": namespace
          },
          "rules" : perm['rules']
        }
        writeResource(role)
        binding = {
          "apiVersion": "rbac.authorization.k8s.io/v1",
          "kind" : "RoleBinding",
          "metadata" : {
            "name" : name,
            "namespace": namespace
          },
          "roleRef" : {
             "apiGroup" : "rbac.authorization.k8s.io",
             "kind" : "Role",
             "name" : name
          },
          "subjects" : [
            {
              "kind":"ServiceAccount",
              "name": name
            }
          ]
        }
        writeResource(binding)

def generateCRDs(csv):
  for crdDef in csv['spec']['customresourcedefinitions']['owned']:
    name = crdDef['name']
    segments = name.split('.')
    crd = {
        "apiVersion": "apiextensions.k8s.io/v1",
        "kind" : "CustomResourceDefinition",
        "metadata" : {
          "name" : name
        },
        "spec" : {
          "group" : '.'.join(segments[1:]),
          "names" : {
            "kind" : crdDef['kind'],
            "listKind" : crdDef['kind']+'List',
            "plural" : segments[0],
            "singular" : crdDef['kind'].lower()
          },
          "scope" : "Namespaced",
          "version" : crdDef['version']
        }
    }
    writeResource(crd)

csv = loadFile(csvFile)
'''
01-namespace
02-sa
03-role
04-rolebinding
05-crd
06-deployment
'''

if not namespace:
    namespace = getNamespace(csv)

excludes = "(?!.*\.clusterserviceversion\.yaml)"
staticFiles = [f for f in os.listdir(csvDir) if re.match(excludes, f)]
staticFiles.sort()
for f in staticFiles:
  staticYaml = loadFile(os.path.join(csvDir,f))
  writeResource(staticYaml)

for kind in kinds.split(','):
  if kind == 'ns':
    generateNamespace(namespace)
  elif kind == 'sa':
    generateServiceAccounts(csv, namespace)
  elif kind == 'clusterrole':
    generateClusterPermissions(csv, namespace)
  elif kind == 'role':
    generatePermissions(csv)
  elif kind == 'dep':
    generateDeployments(csv)
  elif kind == 'crd':
    generateCRDs(csv)
