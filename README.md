# OpenShift Secured Integration

This repository explores some of the integrations with credentials and certificates providers.

- [OpenShift Secured Integration](#openshift-secured-integration)
  - [Introduction](#introduction)
  - [Cert manager](#cert-manager)
    - [Installation and configuration](#installation-and-configuration)
    - [Debugging cert-manager](#debugging-cert-manager)
    - [Useful Links](#useful-links)
  - [Hashicorp Vault](#hashicorp-vault)
    - [Installation and configuration](#installation-and-configuration-1)
    - [Useful Links](#useful-links-1)


## Introduction

This repository demonstrates how to securely integrate an OpenShift cluster with **HashiCorp Vault** for managing secrets and credentials, and **cert-manager** for automating certificate creation and renewal. You'll find deployment guides, step-by-step instructions, and example configurations to streamline your setup. Dive in to simplify and secure your cluster's secrets and certificates management!


## Cert manager

[cert-manager](https://docs.openshift.com/container-platform/4.17/security/cert_manager_operator/index.html) is a Kubernetes add-on to automate the management and issuance of TLS certificates from various issuing sources. It will ensure certificates are valid and up to date periodically, and attempt to renew certificates at an appropriate time before expiry.

### Installation and configuration

In order to split installation of the operator and post-configuration, I've split `cert-manager` resources in two different ArgoCD applications:

1. `cert-manager-operator` will install the operator as well as create aws credentials using the Cluster Credentials Operator to allow the operator to perform DNS requests to validate the URIs of the certificates.
2. `cert-manager-route53` application will create the actual Certificate Issuer and certificates for the API server and the Ingress and apply them to the cluster.

Do you want to deploy it in your cluster **without ArgoCD**? You can copy the following piece of code and execute it in your cluster:

```bash
# 1) Deploy the operator
oc apply -k cert-manager-operator
# 2) Wait for the operator to be ready
echo -n "Waiting for cert-manager pods to be ready..."
while [[ $(oc get pods -l app.kubernetes.io/instance=cert-manager -n cert-manager -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True True True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"
# 3) Configure the certificates
helm template cert-manager-route53 --set clusterDomain=$(oc get dns.config/cluster -o jsonpath='{.spec.baseDomain}')  | oc apply -f -
```

To do list:

* #TODO#: Trust the AWS CA in the ClusterIssuer.
* #TODO#: Add support for self-signed certificates.



### Debugging cert-manager

`cert-manager` is a simple operator, but if you are just starting to play with it, you might need some guidance to better understand what is going on. Here you can find some debugging tips:

* There should be three pods in the `cert-manager` namespace. If not, check the subscription status field.
* Among the pods, the `cert-manager` will contain the validation information, but the `cert-manager-webhook` will show you if `cert-manager` is not trusting your issuer CA.
* The `Certificate` resource is the main object you use to request certificates, but if you want to see the issuing status, check the `certificaterequest` or, more importantly, the `order` resource.
* If you request a cert in a secret `$NAME`, there is an intermediate step in which it will create an auxiliary secret named `$SECRET-suffix` that will then be deleted after proper issuing. Just relax and wait 😄


### Useful Links

* Docs: [cert-manager Operator for Red Hat OpenShift](https://docs.openshift.com/container-platform/4.17/security/cert_manager_operator/index.html).
* Blog: [YAUB - SSL Certificate Management for OpenShift on AWS](https://blog.stderr.at/openshift/2023/02/ssl-certificate-management-for-openshift-on-aws/).
* Blog: [YAUB - Managing Certificates using GitOps approach](https://blog.stderr.at/gitopscollection/2024-07-04-managing-certificates-with-gitops/).
* Blog: [Automatic certificate issuing with IdM and cert-manager operator for OpenShift](https://developers.redhat.com/articles/2024/12/17/automatic-certificate-issuing-idm-and-cert-manager-operator-openshift).
* Blog: [Let's Encrypt - Challenge Types](https://letsencrypt.org/docs/challenge-types/): This is a summary of how challenges work for certificates.



## Hashicorp Vault


HashiCorp Vault is a secrets management tool that integrates seamlessly with OpenShift (OCP) to securely store and manage sensitive information like API keys, credentials, and certificates. It enables dynamic secrets generation and automated secret renewal, reducing manual overhead and improving security. When combined with OCP, Vault ensures that applications running in your cluster can securely access secrets with fine-grained access control, enhancing the overall security posture of your workloads.


### Installation and configuration




### Useful Links


* https://www.youtube.com/watch?v=LDx6pCOahgE&t=2s
* https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-openshift

* https://developer.hashicorp.com/vault/docs/platform/k8s/helm/openshift










