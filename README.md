# rhbk-cert — Automated Certificate Rotation Validated Pattern

A [Red Hat Validated Pattern](https://validatedpatterns.io) that deploys a fully automated TLS certificate rotation circle for [Red Hat Build of Keycloak (RHBK)](https://access.redhat.com/products/red-hat-build-of-keycloak) and OpenShift applications. cert-manager issues and renews certificates; Kuadrant TLSPolicy attaches them to the Istio Gateway; the RHBK operator picks them up automatically — no manual certificate management ever.

**Target application:** [Neuralbank](https://github.com/maximilianoPizarro/from-3scale-to-connectivity-link) secured with OIDC via RHBK and [Red Hat Connectivity Link (Kuadrant)](https://www.redhat.com/en/technologies/cloud-computing/openshift/connectivity-link).

**Documentation (EN/ES):** https://maximilianopizarro.github.io/rhbk-cert/

---

## Certificate Rotation Circle

```
ClusterIssuer (ACME DNS01 / Internal CA)
  │
  ├─► cert-manager Certificate [keycloak-system/rhbk-tls-secret]
  │       └─► RHBK Operator detects Secret change → rolling restart (~1 min)
  │               └─► Keycloak serves HTTPS with renewed cert
  │
  └─► Kuadrant TLSPolicy → cert-manager Certificate [neuralbank-stack/neuralbank-gateway-tls]
          └─► Istio Gateway hot-reloads cert (zero downtime)
                  └─► Neuralbank HTTPRoute → OIDC secured via RHBK
```

Renewal is automatic. When cert-manager renews a certificate it updates the Kubernetes Secret in-place. The Gateway hot-reloads without restart. RHBK restarts within one minute. No GitOps change required.

---

## OpenShift Node Requirements

| Resource | Minimum | Recommended |
|---|---|---|
| OCP version | 4.17 | 4.20 |
| Control plane nodes | 3 × 4 vCPU / 16 GB RAM | 3 × 8 vCPU / 32 GB RAM |
| Worker nodes | 3 × 8 vCPU / 32 GB RAM | 3 × 16 vCPU / 64 GB RAM |
| Storage class | RWO, 50 GB/worker | RWO, 100 GB/worker |
| DNS | Wildcard `*.apps.<cluster-domain>` → LB | Same |
| OCP Operator Catalog | `redhat-operators` accessible | Same |

---

## Operators Deployed

| Operator | Channel | Catalog Source |
|---|---|---|
| Red Hat OpenShift GitOps | stable | redhat-operators |
| cert-manager Operator for Red Hat OpenShift | stable-v1 | redhat-operators |
| External Secrets Operator | stable-v1 | redhat-operators |
| Red Hat OpenShift Service Mesh 3 (Sail) | stable-3.2 | redhat-operators |
| Red Hat Connectivity Link (Kuadrant) | stable | redhat-operators |
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

- OpenShift CLI: `oc` v4.17+
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

# Gateway certificate issued by Kuadrant TLSPolicy
oc get certificate -n neuralbank-stack

# Keycloak instance running with TLS
oc get keycloak -n keycloak-system rhbk

# End-to-end HTTPS test
curl https://rhbk.<cluster-domain>/realms/master
```

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
- [cert-manager Operator for Red Hat OpenShift](https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html/security_and_compliance/cert-manager-operator-for-red-hat-openshift)
- [Red Hat Build of Keycloak Operator](https://access.redhat.com/documentation/en-us/red_hat_build_of_keycloak)
- [Red Hat Connectivity Link (Kuadrant)](https://docs.kuadrant.io)
- [Red Hat OpenShift Service Mesh](https://docs.redhat.com/en/documentation/red_hat_openshift_service_mesh)
