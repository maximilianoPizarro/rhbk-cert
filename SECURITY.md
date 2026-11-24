# Security

Report a vulnerability privately through GitHub Security Advisories on https://github.com/maximilianoPizarro/rhbk-cert/security/advisories/new.

Do not open a public issue for a credential leak, a cluster takeover, or an exploitable certificate-handling bug. Do not include live tokens, Vault keys, or `values-secret.yaml` contents in the report.

This pattern stores DNS and Keycloak credentials in Vault and expects `values-secret.yaml` to stay out of Git. Rotate those credentials in Vault if they were exposed.
