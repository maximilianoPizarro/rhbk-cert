# rhbk-cert — Automated Certificate Rotation Validated Pattern

A [Red Hat Validated Pattern](https://validatedpatterns.io) that deploys a fully automated TLS certificate rotation circle for [Red Hat Build of Keycloak (RHBK)](https://access.redhat.com/products/red-hat-build-of-keycloak) and OpenShift applications. cert-manager issues and renews certificates; Connectivity Link TLSPolicy attaches them to the Service Mesh Gateway; the RHBK operator picks them up automatically — no manual certificate management ever.

**Example RHBK client:** [Neuralbank](https://github.com/maximilianoPizarro/from-3scale-to-connectivity-link) is a sample application secured with OIDC through RHBK and [Red Hat Connectivity Link](https://www.redhat.com/en/technologies/cloud-computing/connectivity-link). Chart `charts/all/neuralbank` deploys the frontend, the API, and PostgreSQL in `neuralbank-stack`. The Gateway HTTPRoute sends `/` to the frontend and `/api` to the API. The Connectivity Link AuthPolicy checks the RHBK JWT on `/api`. Another client can attach its own HTTPRoute to the same Gateway.

**Documentation (EN/ES):** https://maximilianopizarro.github.io/rhbk-cert/

---

## Certificate Rotation Circle

cert-manager issues `rhbk-tls-secret` for Red Hat build of Keycloak and, through a Connectivity Link TLSPolicy, `neuralbank-gateway-tls` for the Service Mesh Gateway. Renewal updates the Secret in place. The Gateway reloads it without a pod restart. With one RHBK replica the operator rollout interrupts HTTPS for about a minute; two replicas avoid that. The diagram is on the documentation site.

---

## OpenShift Node Requirements

| Resource | Minimum | Recommended |
|---|---|---|
| OCP version | 4.19 | 4.20 |
| Control plane nodes | 3 × 4 vCPU / 16 GB RAM | 3 × 8 vCPU / 32 GB RAM |
| Worker nodes | 3 × 8 vCPU / 32 GB RAM | 3 × 16 vCPU / 64 GB RAM |
| Storage class | RWO, 50 GB/worker | RWO, 100 GB/worker |
| DNS | Wildcard `*.apps.<cluster-domain>` → LB | Same |
| OCP Operator Catalog | `redhat-operators` accessible | Same |

OpenShift 4.19 is the minimum because that is the first release where Red Hat Connectivity Link and OpenShift Service Mesh 3 are supported. 4.20 remains the recommended release.

---

## Operators Deployed

| Operator | Channel | Catalog Source |
|---|---|---|
| Red Hat OpenShift GitOps | stable | redhat-operators |
| cert-manager Operator for Red Hat OpenShift | stable-v1 | redhat-operators |
| External Secrets Operator | stable-v1 | redhat-operators |
| Red Hat OpenShift Service Mesh 3 (Sail) | stable-3.2 | redhat-operators |
| Red Hat Connectivity Link | stable | redhat-operators |
| Red Hat Build of Keycloak | stable-v26.4 | redhat-operators |

All operators are sourced from the official Red Hat Operator Catalog (`redhat-operators`). No community or third-party catalogs required.

---

## DNS Provider Support

The pattern supports the following ACME DNS01 providers. Set `acme.provider` in the chart or via Pattern CR `extraParameters`, then fill in the credentials in `values-secret.yaml`.

| Provider | `acme.provider` value | Credential secret key |
|---|---|---|
| AWS Route 53 | `route53` | `secret-access-key` |
| Cloudflare | `cloudflare` | `api-token` |
| Azure DNS | `azure` | `client-secret` |
| Google Cloud DNS | `google` | `key.json` |
| ACME DNS (self-hosted) | `acmedns` | `acmedns.json` |

For internal/air-gapped clusters, set `acme.enabled: false` and `selfSigned.enabled: true`. A self-signed CA ClusterIssuer is created automatically.

---

## Prerequisites

- OpenShift CLI: `oc` v4.19+
- Helm: `helm` v3.14+
- GNU Make: `make`
- Cluster-admin access on the target OpenShift cluster
- DNS provider API credentials for ACME DNS01 (or use `selfSigned.enabled: true` for internal clusters)
- [Validated Patterns Operator](https://validatedpatterns.io/learn/quickstart/) installed on the cluster

---

## Installation

```bash
# 1. Clone the repository
git clone https://github.com/maximilianoPizarro/rhbk-cert.git
cd rhbk-cert

# 2. Configure secrets
cp values-secret.yaml.template values-secret.yaml
# Edit values-secret.yaml and fill in:
#   - keycloak-initial-admin: Keycloak admin username and password
#   - keycloak-db-secret: PostgreSQL username and password
#   - dns-credentials: DNS provider credentials (see DNS Provider Support above)
vi values-secret.yaml

# 3. Deploy the pattern
make install
```

`make install` installs the Validated Patterns Operator (if not present), loads secrets into HashiCorp Vault, and applies the Pattern CR. ArgoCD then syncs all components in wave order.

---

## Verify

```bash
# cert-manager ClusterIssuer ready
oc get clusterissuer letsencrypt-prod

# RHBK certificate issued by cert-manager
oc get certificate -n keycloak-system rhbk-tls

# Gateway certificate issued by Connectivity Link TLSPolicy
oc get certificate -n neuralbank-stack

# Keycloak instance running with TLS
oc get keycloak -n keycloak-system rhbk

# End-to-end HTTPS test
curl https://rhbk.<cluster-domain>/realms/master
```

---

## Vault and the RHBK login

Vault is sealed after a restart. The init data, including the root token and the unseal keys, is in Secret `vaultkeys` in namespace `imperative`. Do not commit that output.

```bash
# Vault UI
oc get route vault -n vault -o jsonpath='https://{.spec.host}{"\n"}'

# root_token logs in to the UI. unseal_keys_b64 unseals Vault.
oc get secret vaultkeys -n imperative -o go-template='{{index .data "vault_data_json" | base64decode}}{{"\n"}}'
```

The user that can sign in to the RHBK admin console is the bootstrap admin from `values-secret.yaml` (`keycloak-initial-admin`). External Secrets copies it to Secret `keycloak-initial-admin` in `keycloak-system`.

```bash
# Admin console. The route name is generated, so list the namespace.
oc get route -n keycloak-system -o jsonpath='https://{.items[0].spec.host}/admin{"\n"}'

oc get secret keycloak-initial-admin -n keycloak-system \
  -o go-template='username={{.data.username | base64decode}}{{"\n"}}password={{.data.password | base64decode}}{{"\n"}}'
```

Sign in on the master realm with that username and password.

Neuralbank has its own test user in realm `neuralbank`. A Job creates that realm, the public client `neuralbank-frontend`, and the user from Secret `neuralbank-user`.

```bash
host=$(oc get route -n keycloak-system -o jsonpath='{.items[0].spec.host}')
echo "https://neuralbank.${host#rhbk.}/"

oc get secret neuralbank-user -n neuralbank-stack \
  -o go-template='username={{.data.username | base64decode}}{{"\n"}}password={{.data.password | base64decode}}{{"\n"}}'
```

Open that URL and sign in on realm `neuralbank` with that username and password.

---

## Extending to New Applications

Adding a new HTTPS-secured application requires three resources. The existing ClusterIssuer and TLSPolicy already cover the Gateway — no cert changes needed.

**1. Add an HTTPRoute pointing to the existing Gateway:**

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-new-app
  namespace: neuralbank-stack
spec:
  parentRefs:
    - name: neuralbank-gateway
      namespace: neuralbank-stack
  hostnames:
    - my-new-app.<cluster-domain>
  rules:
    - backendRefs:
        - name: my-new-app
          port: 8080
```

**2. (Optional) Secure with OIDC via RHBK:**

```yaml
apiVersion: kuadrant.io/v1
kind: AuthPolicy
metadata:
  name: my-new-app-oidc
  namespace: neuralbank-stack
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: my-new-app
  rules:
    authentication:
      jwt:
        jwt:
          issuerUrl: https://rhbk.<cluster-domain>/realms/<realm-name>
```

**3.** Add the new resources to your GitOps source (this repository or the application repository). ArgoCD syncs them automatically.

---

## References

- [Validated Patterns Framework](https://validatedpatterns.io)
- [cert-manager Operator for Red Hat OpenShift](https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html/security_and_compliance/cert-manager-operator-for-red-hat-openshift)
- [Red Hat Build of Keycloak Operator](https://access.redhat.com/documentation/en-us/red_hat_build_of_keycloak)
- [Red Hat Connectivity Link](https://docs.redhat.com/en/documentation/red_hat_connectivity_link)
- [Red Hat OpenShift Service Mesh](https://docs.redhat.com/en/documentation/red_hat_openshift_service_mesh)
