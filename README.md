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
    - [3.2. Initializing Vault Secrets](#32-initializing-vault-secrets)
    - [3.3. Useful Links](#33-useful-links)
  - [4. Handling secrets on OpenShift](#4-handling-secrets-on-openshift)
  - [5. Vault Sidecar Agent Injector](#5-vault-sidecar-agent-injector)
    - [6.1. Installation and configuration](#61-installation-and-configuration)
    - [6.2. Useful Links](#62-useful-links)
    - [6.3. ⚖️ Pros and Cons of Vault Sidecar Agent Injector](#63-️-pros-and-cons-of-vault-sidecar-agent-injector)
  - [6. Secrets Store CSI Driver](#6-secrets-store-csi-driver)
    - [6.1. Installation and configuration](#61-installation-and-configuration-1)
    - [6.2. Useful Links](#62-useful-links-1)
    - [6.3. ⚖️ Pros and Cons of the Secrets Store CSI Driver](#63-️-pros-and-cons-of-the-secrets-store-csi-driver)
  - [7. Vault Secrets Operator (VSO)](#7-vault-secrets-operator-vso)
    - [7.1. Installation and configuration](#71-installation-and-configuration)
    - [7.2. Useful Links](#72-useful-links)
    - [7.3. ⚖️ Pros and Cons of the Vault Secrets Operator](#73-️-pros-and-cons-of-the-vault-secrets-operator)
  - [8. External Secrets Operator (ESO)](#8-external-secrets-operator-eso)
    - [8.1. Installation and configuration](#81-installation-and-configuration)
    - [8.2. Useful Links](#82-useful-links)
  - [9. ArgoCD Vault Plugin](#9-argocd-vault-plugin)


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
oc apply -f application-03-hashicorp-vault-server.yaml
```

In order to access the deployed Vault server, just retrieve the route using the following command and access the UI using the token `root`:

```bash
oc get route hashicorp-vault-server -n vault --template="https://{{.spec.host}}"
```


### 3.2. Initializing Vault Secrets

As the `dev` Vault instance is an in-memory instance, just by deleting the `vault-0` pod, you will loose all the data stored in the Vault. For that reason, I have created a script to quickly set up the Secret store with some dummy data to consume from the applications. The only thing that you need is log in to the cluster and execute the following script:

```bash
./create_vault_secrets.sh
```

Now, you can access the Hashicorp Vault, to the `secret/` Engine and you will see the `demo1`, `demo2`, and `demo3` entries.




### 3.3. Useful Links

* Git: [GitHub - vault-helm](https://github.com/hashicorp/vault-helm/tree/main). Official repo of the Hashicorp Vault Helm repo.
* Blog: [In-Depth Hashicorp Vault setup on OpenShift using OpenShift GitOps](https://stephennimmo.com/2024/05/05/hashicorp-vault-setup-on-openshift-using-argocd): This is a must read. It is an updated blog on how to customize the Hashicorp Vault deployment.
* Hashicorp Tutorial: [Install Vault to Red Hat OpenShift](https://developer.hashicorp.com/vault/docs/platform/k8s/helm/openshift) 












## 4. Handling secrets on OpenShift

Managing secrets securely is a cornerstone of modern application security. OpenShift, while offering built-in support for Kubernetes secrets, benefits greatly from the advanced features and dynamic nature of HashiCorp Vault. This section explores multiple approaches to integrate Vault with OCP, evaluating their benefits, drawbacks, and integration with ArgoCD.

Here are some common methods for using secrets from HashiCorp Vault in OpenShift environments:


| **Tool**                           | **Description**                           | **Advantages**                                   | **Disadvantages**                                  |
|------------------------------------|-------------------------------------------|--------------------------------------------------|----------------------------------------------------|
| **HashiCorp Vault API**            | Direct integration with applications      | Dynamic secrets, centralized management          | Needs integration in application code, dependency on Vault availability. |
| **Vault Sidecar Agent Injector**           | Injects secrets into pods via a sidecar   | Secrets not stored in Kubernetes Secrets.  | Requires sidecar for each pod. Only works for pods.      |
| **Secrets Store CSI Driver**       | Mounts secrets as volumes in pods         | Simplifies secret consumption, works across multiple backends | Secrets not dynamically refreshed, requires additional driver. Only works for pods. |
| **Vault Secrets Operator** (VSO)   | Syncs Vault secrets to Kubernetes Secrets | Kubernetes-native integration, automates secret updates | Secrets stored in Kubernetes Secrets. |
| **External Secrets Operator** (ESO)| Syncs secrets from external providers     | Multi-provider support, GitOps-friendly          | Secrets persisted in Kubernetes Secrets, sync delays possible. |
| **ArgoCD Vault Plugin**            | Fetches secrets during manifest rendering | Tight GitOps integration, supports encrypted secrets | Adds complexity to the pipeline setup. Plugins are not in RH support.       |


> [!TIP]
> The first method just implies using app framework libraries or pre-exec scripts to retrieve the Secrets from the Hashicorp Vault manually and add them to the application. For that reason, we are not going to explore that possibility.





## 5. Vault Sidecar Agent Injector

The [Vault Agent Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector) alters pod specifications to include Vault Agent containers that render Vault secrets to a shared memory volume using Vault Agent Templates. By rendering secrets to a shared volume, containers within the pod can consume Vault secrets without being Vault aware.

The injector is a Kubernetes Mutation Webhook Controller. The controller intercepts pod events and applies mutations to the pod if annotations exist within the request. This functionality is provided by the vault-k8s project and can be automatically installed and configured using the Vault Helm chart.


### 6.1. Installation and configuration


```bash
oc apply -f application-05-vault-sidecar-agent-injector.yaml
```

> [!WARNING]
> If this application is not rendered correctly in your ArgoCD, consider adding the [following flag](https://github.com/alvarolop/ocp-gitops-playground/blob/main/openshift/02-argocd.yaml#L70) to your kustomize configuration: `--enable-helm`.

or deploy it locally with the following command `kustomize build 05-vault-sidecar-agent-injector/ --enable-helm | oc apply -f -`.

### 6.2. Useful Links

* Docs: [Hashicorp - Vault Agent Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector).
* Tutorial: [Hashicorp - Mange secrets by injecting a Vault Agent container](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar).



### 6.3. ⚖️ Pros and Cons of Vault Sidecar Agent Injector

#### ✅ Pros
* 🔧 Easy configuration based on several annotations.
* 🔑 Authentication based on ServiceAccount Tokens.

#### ❌ Cons
* 🛠️ Requires modifying application deployment configurations.
* 🔒 Secrets can only be injected into containers, not OpenShift configuration.
* 📂 Secrets can only be injected as files, not environment variables.
* ❌ Not supported by Red Hat.
* ⚡ High resources consumption as each pod with secret needs a permanent sidecar container.

#### 💡 Other Considerations
* 🚀 Installation does not require an operator.










## 6. Secrets Store CSI Driver

The [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/introduction) `secrets-store.csi.k8s.io` allows Kubernetes to mount multiple secrets, keys, and certs stored in enterprise-grade external secrets stores into their pods as a volume. Once the Volume is attached, the data in it is mounted into the container’s file system. 

The following secrets store providers are available for use with the Secrets Store CSI Driver Operator:

* AWS Secrets Manager.
* AWS Systems Manager Parameter Store.
* Azure Key Vault.
* Google Secret Manager.
* HashiCorp Vault.



### 6.1. Installation and configuration


```bash
oc apply -f application-06-secrets-store-csi-driver.yaml
```

### 6.2. Useful Links

* Docs: [OpenShift - Installing Secrets CSI](https://docs.openshift.com/container-platform/4.17/storage/container_storage_interface/persistent-storage-csi-secrets-store.html).
* Docs: [OpenShift - Providing sensitive data to pods by using an external secrets store](https://docs.openshift.com/container-platform/4.17/nodes/pods/nodes-pods-secrets-store.html#mounting-secrets-external-secrets-store).
* Docs: [Kubernetes Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/introduction).



### 6.3. ⚖️ Pros and Cons of the Secrets Store CSI Driver

#### ✅ Pros
* 🔧 Easy configuration based on several annotations.
* 🔑 Authentication based on ServiceAccount Tokens.

#### ❌ Cons
* 🛠️ Requires modifying application deployment configurations.
* 🔒 Secrets can only be injected into containers, not OpenShift configuration.
* 📂 Secrets can only be injected as files, not environment variables.
* ❌ Not supported by Red Hat.

#### 💡 Other Considerations
* 🚀 Installation does not require an operator.
* 📲 The Secrets Store CSI Driver operator is **Tech Preview** in OpenShift 4.17.






## 7. Vault Secrets Operator (VSO)

[The Vault Secrets Operator](https://developer.hashicorp.com/vault/docs/platform/k8s/vso/openshift) allows Pods to consume Vault secrets and HCP Vault Secrets Apps natively from Kubernetes Secrets. The Operator writes the source Vault secret data directly to the destination Kubernetes Secret, ensuring that any changes made to the source are replicated to the destination over its lifetime.


### 7.1. Installation and configuration


```bash
oc apply -f application-vault-secrets-operator.yaml
```


### 7.2. Useful Links

* Blog: [Vault Secrets Operator for Kubernetes now GA](https://www.hashicorp.com/blog/vault-secrets-operator-for-kubernetes-now-ga).


### 7.3. ⚖️ Pros and Cons of the Vault Secrets Operator

#### ✅ Pros


#### ❌ Cons


#### 💡 Other Considerations












## 8. External Secrets Operator (ESO)

[External Secrets Operator](https://external-secrets.io/latest) is a Kubernetes operator that integrates external secret management systems like AWS Secrets Manager, HashiCorp Vault, Google Secrets Manager, Azure Key Vault, IBM Cloud Secrets Manager, CyberArk Conjur, Pulumi ESC and many more. The operator reads information from external APIs and automatically injects the values into a Kubernetes Secret.


### 8.1. Installation and configuration

External-secrets can be managed by Operator Lifecycle Manager (OLM) via an installer operator. This is the best alternative for OpenShift. This operator can be installed using the following ArgoCD application:

```bash
oc apply -f application-external-secrets-operator.yaml
```

### 8.2. Useful Links


* https://external-secrets.io/latest/
* https://github.com/external-secrets/external-secrets-helm-operator
* https://www.redhat.com/en/blog/external-secrets-with-hashicorp-vault










## 9. ArgoCD Vault Plugin


* argocd-vault-plugin: https://github.com/argoproj-labs/argocd-vault-plugin
