# Changelog

## 1.0.0

- Initial Validated Pattern for certificate rotation with cert-manager, Red Hat build of Keycloak, Connectivity Link, and Service Mesh.
- Documentation site in English and Spanish.

## Unreleased

- Operator documentation for verification, renewal settings, trust, DNS credential rotation, alerts, security, the tested version matrix, uninstall, and availability during rotation.
- Opt-in Let's Encrypt staging issuer, conditional PodDisruptionBudget, and an opt-in PrometheusRule.
- `scripts/preflight.sh` checks OpenShift version, the Red Hat catalog, a StorageClass, and the Ingress domain before install.
