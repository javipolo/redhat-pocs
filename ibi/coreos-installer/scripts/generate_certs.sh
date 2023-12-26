#!/bin/bash
set -e

CA_NAME="my-ca"
CA_COMMON_NAME="admin-kubeconfig-signer"
USER_NAME="system:admin"
LOADBALANCER_SIGNER_NAME="loadbalancer-serving-signer"
LOCALHOST_SIGNER_NAME="localhost-serving-signer"
SERVICE_NETWORK_SIGNER_NAME="service-network-serving-signer"
INGRESS_OPERATOR_SIGNER_NAME="ingresskey-ingress-operator"

CLUSTER_NAME="other-test-sno.example.com"

CERT_DIR="./certs"
CONFIG_CERT_DIR="./config/certs"
KUBECONFIG_FILE="kubeconfig"

# Create the certificate directory
mkdir -p "${CERT_DIR}"
mkdir -p "${CONFIG_CERT_DIR}"

# Generate a private key for the CA
openssl genpkey -algorithm RSA -out "${CERT_DIR}/${CA_NAME}-key.pem"

# Create a CSR for the CA
openssl req -new -key "${CERT_DIR}/${CA_NAME}-key.pem" -out "${CERT_DIR}/${CA_NAME}-csr.pem" -subj "/CN=${CA_COMMON_NAME}"

# Self-sign the CSR to generate the CA certificate
openssl x509 -req -in "${CERT_DIR}/${CA_NAME}-csr.pem" -signkey "${CERT_DIR}/${CA_NAME}-key.pem" -out "${CERT_DIR}/${CA_NAME}.crt"

# Generate a private key for the user
openssl genpkey -algorithm RSA -out "${CERT_DIR}/${USER_NAME}-key.pem"

# Generate a CSR for the user
openssl req -new -key "${CERT_DIR}/${USER_NAME}-key.pem" -out "${CERT_DIR}/${USER_NAME}-csr.pem" -subj "/CN=${USER_NAME}"

# Sign the user's CSR with the CA
openssl x509 -req -in "${CERT_DIR}/${USER_NAME}-csr.pem" -CA "${CERT_DIR}/${CA_NAME}.crt" -CAkey "${CERT_DIR}/${CA_NAME}-key.pem" -CAcreateserial -out "${CERT_DIR}/${USER_NAME}-crt.pem" -days 365

# Function to generate signer key and certificate
generate_signer() {
  local SIGNER_NAME="$1"
  local COMMON_NAME="$2"
  openssl genpkey -algorithm RSA -out "${CERT_DIR}/${SIGNER_NAME}.key"
  openssl req -new -key "${CERT_DIR}/${SIGNER_NAME}.key" -out "${CERT_DIR}/${SIGNER_NAME}-csr.pem" -subj "/CN=${COMMON_NAME}"
  openssl x509 -req -in "${CERT_DIR}/${SIGNER_NAME}-csr.pem" -CA "${CERT_DIR}/${CA_NAME}.crt" -CAkey "${CERT_DIR}/${CA_NAME}-key.pem" -CAcreateserial -out "${CERT_DIR}/${SIGNER_NAME}.crt" -days 365
  # Copy the signer key to the certs dir under the config directory
  cp "${CERT_DIR}/${SIGNER_NAME}.key" ${CONFIG_CERT_DIR}/ 
}
# Copy the CA certificate used to sign the system:admin-crt.pem into config/certs as the admin-kubeconfig-client-ca.crt
cp "${CERT_DIR}/${CA_NAME}.crt" ${CONFIG_CERT_DIR}/admin-kubeconfig-client-ca.crt

# Generate signer keys and certificates
generate_signer "${LOADBALANCER_SIGNER_NAME}" "kube-apiserver-lb-signer"
generate_signer "${LOCALHOST_SIGNER_NAME}" "kube-apiserver-localhost-signer"
generate_signer "${SERVICE_NETWORK_SIGNER_NAME}" "kube-apiserver-service-network-signer"
generate_signer "${INGRESS_OPERATOR_SIGNER_NAME}" "ingress-operator@1702987194"

# Set the cluster context in kubeconfig
kubectl config set-cluster "${CLUSTER_NAME}" --server="https://api.${CLUSTER_NAME}:6443" --certificate-authority="${CERT_DIR}/${LOADBALANCER_SIGNER_NAME}.crt" --embed-certs=true --kubeconfig="${KUBECONFIG_FILE}"

# Set the user in kubeconfig
kubectl config set-credentials "${USER_NAME}" --client-certificate="${CERT_DIR}/${USER_NAME}-crt.pem" --client-key="${CERT_DIR}/${USER_NAME}-key.pem" --embed-certs=true --kubeconfig="${KUBECONFIG_FILE}"

# Set the loadbalancer-serving-signer in kubeconfig
kubectl config set-credentials "${LOADBALANCER_SIGNER_NAME}" --client-certificate="${CERT_DIR}/${LOADBALANCER_SIGNER_NAME}.crt" --client-key="${CERT_DIR}/${LOADBALANCER_SIGNER_NAME}.key" --embed-certs=true --kubeconfig="${KUBECONFIG_FILE}"

# Set the context in kubeconfig
kubectl config set-context "${USER_NAME}" --cluster="${CLUSTER_NAME}" --user="${USER_NAME}" --kubeconfig="${KUBECONFIG_FILE}"

# Use the context in kubeconfig
kubectl config use-context "${USER_NAME}" --kubeconfig="${KUBECONFIG_FILE}"

echo "Kubeconfig file and certificates generated successfully."

