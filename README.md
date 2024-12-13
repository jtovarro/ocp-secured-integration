# OpenShift Secure Integration

This repository explores some of the integrations with credentials and certificates providers.

- [OpenShift Secure Integration](#openshift-secure-integration)
  - [Introduction](#introduction)
  - [Hashicorp Vault](#hashicorp-vault)
  - [Cert manager](#cert-manager)
  - [Useful Links](#useful-links)


## Introduction

This repository demonstrates how to securely integrate an OpenShift cluster with HashiCorp Vault for managing secrets and credentials, and cert-manager for automating certificate creation and renewal. You'll find deployment guides, step-by-step instructions, and example configurations to streamline your setup. Dive in to simplify and secure your cluster's secrets and certificates management!


## Hashicorp Vault


HashiCorp Vault is a secrets management tool that integrates seamlessly with OpenShift (OCP) to securely store and manage sensitive information like API keys, credentials, and certificates. It enables dynamic secrets generation and automated secret renewal, reducing manual overhead and improving security. When combined with OCP, Vault ensures that applications running in your cluster can securely access secrets with fine-grained access control, enhancing the overall security posture of your workloads.



* https://www.youtube.com/watch?v=LDx6pCOahgE&t=2s
* https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-openshift

* https://developer.hashicorp.com/vault/docs/platform/k8s/helm/openshift

## Cert manager

cert-manager is a Kubernetes add-on to automate the management and issuance of TLS certificates from various issuing sources. It will ensure certificates are valid and up to date periodically, and attempt to renew certificates at an appropriate time before expiry.



* https://docs.openshift.com/container-platform/4.16/security/cert_manager_operator/index.html
* https://operatorhub.io/operator/cert-manager


## Useful Links


