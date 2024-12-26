# OpenShift Secured Integration

This repository explores some of the integrations with credentials and certificates providers.

- [OpenShift Secured Integration](#openshift-secured-integration)
  - [1. Introduction](#1-introduction)
  - [2. Cert manager](#2-cert-manager)
    - [2.1. Installation and configuration](#21-installation-and-configuration)
    - [2.2. Debugging cert-manager](#22-debugging-cert-manager)
    - [2.3. Useful Links](#23-useful-links)
  - [3. Hashicorp Vault](#3-hashicorp-vault)
    - [3.1. Installation and access](#31-installation-and-access)
    - [3.2. Useful Links](#32-useful-links)
  - [4. External Secrets Operator](#4-external-secrets-operator)
    - [4.1. Installation and configuration](#41-installation-and-configuration)
    - [4.2. Useful Links](#42-useful-links)


## 1. Introduction

This repository demonstrates how to securely integrate an OpenShift cluster with **HashiCorp Vault** for managing secrets and credentials, and **cert-manager** for automating certificate creation and renewal. You'll find deployment guides, step-by-step instructions, and example configurations to streamline your setup. Dive in to simplify and secure your cluster's secrets and certificates management!


## 2. Cert manager

[cert-manager](https://docs.openshift.com/container-platform/4.17/security/cert_manager_operator/index.html) is a Kubernetes add-on to automate the management and issuance of TLS certificates from various issuing sources. It will ensure certificates are valid and up to date periodically, and attempt to renew certificates at an appropriate time before expiry.

### 2.1. Installation and configuration

In order to split installation of the operator and post-configuration, I've split `cert-manager` resources in three different ArgoCD applications:

1. `cert-manager-operator` will install the operator as well as create aws credentials using the Cluster Credentials Operator to allow the operator to perform DNS requests to validate the URIs of the certificates. It also configures metrics retrieval so that you can configure its metrics (Prefixed by `certmanager_`).
2. `cert-manager-route53` application will create the actual Certificate Issuer and certificates for the API server and the Ingress and apply them to the cluster.
3. `cert-manager-self-signed` is just a configuration example on how to create a self-signed certificate and use it to issue certificates for your own services. This does not have a real use-case, it is just a demonstration.

Do you want to deploy it in your cluster **without ArgoCD**? You can copy the following piece of code and execute it in your cluster:

```bash
# 1) Deploy the operator
oc apply -k cert-manager-operator
# 2) Wait for the operator to be ready
echo -n "Waiting for cert-manager pods to be ready..."
while [[ $(oc get pods -l app.kubernetes.io/instance=cert-manager -n cert-manager -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True True True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"
# 3) Configure the OpenShift certificates for Ingress and API
helm template cert-manager-route53 --set clusterDomain=$(oc get dns.config/cluster -o jsonpath='{.spec.baseDomain}')  | oc apply -f -
# 4) Configure custom certificates using self-signed
oc apply -k cert-manager-self-signed
```


### 2.2. Debugging cert-manager

`cert-manager` is a simple operator, but if you are just starting to play with it, you might need some guidance to better understand what is going on. Here you can find some debugging tips:

* There should be three pods in the `cert-manager` namespace. If not, check the subscription status field.
* Among the pods, the `cert-manager` will contain the validation information, but the `cert-manager-webhook` will show you if `cert-manager` is not trusting your issuer CA.
* The `Certificate` resource is the main object you use to request certificates, but if you want to see the issuing status, check the `certificaterequest` or, more importantly, the `order` resource.
* If you request a cert in a secret `$NAME`, there is an intermediate step in which it will create an auxiliary secret named `$SECRET-suffix` that will then be deleted after proper issuing. Just relax and wait 😄

```bash
oc get certificate,certificaterequest,order -A
```

Check the certificate used in the connections:

```bash
echo Q | openssl s_client -connect $(oc get route console -n openshift-console --template="{{.spec.host}}"):443 -showcerts 2>/dev/null | openssl x509 -noout -subject -issuer -enddate
```

### 2.3. Useful Links

* Docs: [cert-manager Operator for Red Hat OpenShift](https://docs.openshift.com/container-platform/4.17/security/cert_manager_operator/index.html).
* Blog: [YAUB - SSL Certificate Management for OpenShift on AWS](https://blog.stderr.at/openshift/2023/02/ssl-certificate-management-for-openshift-on-aws/).
* Blog: [YAUB - Managing Certificates using GitOps approach](https://blog.stderr.at/gitopscollection/2024-07-04-managing-certificates-with-gitops/).
* Blog: [Automatic certificate issuing with IdM and cert-manager operator for OpenShift](https://developers.redhat.com/articles/2024/12/17/automatic-certificate-issuing-idm-and-cert-manager-operator-openshift).
* Blog: [Let's Encrypt - Challenge Types](https://letsencrypt.org/docs/challenge-types/): This is a summary of how challenges work for certificates.
* Git: [Cert Manager Mixin](https://gitlab.com/uneeq-oss/cert-manager-mixin) is a collection of reusable and configurable Prometheus alerts, and a Grafana dashboard to help with operating cert-manager.












## 3. Hashicorp Vault


[HashiCorp Vault](https://www.hashicorp.com/products/vault) is a secrets management tool that integrates seamlessly with OpenShift (OCP) to securely store and manage sensitive information like API keys, credentials, and certificates. It enables dynamic secrets generation and automated secret renewal, reducing manual overhead and improving security. When combined with OCP, Vault ensures that applications running in your cluster can securely access secrets with fine-grained access control, enhancing the overall security posture of your workloads.


### 3.1. Installation and access

To install Hashicorp Vault on OpenShift, the recommended mechanism is to deploy it with the Helm Chart. For that reason, I've created the following application with the simplest configuration to deploy on OpenShift and automatically create a Route in `dev` mode:

```bash
oc apply -f application-hashicorp-vault.yaml
```

In order to access the deployed Vault server, just retrieve the route using the following command and access the UI using the token `root`:

```bash
oc get route hashicorp-vault -n hashicorp-vault --template="https://{{.spec.host}}"
```





### 3.2. Useful Links

* Git: [GitHub - vault-helm](https://github.com/hashicorp/vault-helm/tree/main). Official repo of the Hashicorp Vault Helm repo.
* Blog: [In-Depth Hashicorp Vault setup on OpenShift using OpenShift GitOps](https://stephennimmo.com/2024/05/05/hashicorp-vault-setup-on-openshift-using-argocd): This is a must read. It is an updated blog on how to customize the Hashicorp Vault deployment.

* https://www.youtube.com/watch?v=LDx6pCOahgE&t=2s
* https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-openshift
* https://developer.hashicorp.com/vault/docs/platform/k8s/helm/openshift






## 4. External Secrets Operator

[External Secrets Operator](https://external-secrets.io/latest) is a Kubernetes operator that integrates external secret management systems like AWS Secrets Manager, HashiCorp Vault, Google Secrets Manager, Azure Key Vault, IBM Cloud Secrets Manager, CyberArk Conjur, Pulumi ESC and many more. The operator reads information from external APIs and automatically injects the values into a Kubernetes Secret.


### 4.1. Installation and configuration

External-secrets can be managed by Operator Lifecycle Manager (OLM) via an installer operator. This is the best alternative for OpenShift. This operator can be installed using the following ArgoCD application:

```bash
oc apply -f application-external-secrets-operator.yaml
```

### 4.2. Useful Links


* https://external-secrets.io/latest/
* https://github.com/external-secrets/external-secrets-helm-operator
