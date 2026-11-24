# Changelog

## 1.0.0

- Initial Validated Pattern for certificate rotation with cert-manager, Red Hat build of Keycloak, Connectivity Link, and Service Mesh.
- Documentation site in English and Spanish.

## Unreleased

- Use the official Keycloak favicon on the documentation site.
- Deploy Neuralbank, the example RHBK client, from chart `charts/all/neuralbank`. The Gateway sends `/api` through a Connectivity Link AuthPolicy.
- README commands to read the Vault root token and the RHBK bootstrap admin from cluster Secrets.
- Minimum OpenShift is 4.19, the first release that supports Red Hat Connectivity Link and OpenShift Service Mesh 3.
- Operator documentation for verification, renewal settings, trust, DNS credential rotation, alerts, security, the tested version matrix, uninstall, and availability during rotation.
- Opt-in Let's Encrypt staging issuer, conditional PodDisruptionBudget, and an opt-in PrometheusRule.
- `scripts/preflight.sh` checks OpenShift version, the Red Hat catalog, a StorageClass, and the Ingress domain before install.
