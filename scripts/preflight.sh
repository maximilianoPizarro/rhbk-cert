#!/usr/bin/env bash
# Check the cluster before make install. This script is not called by the Makefile:
# pattern install runs inside the Validated Patterns utility container.
set -euo pipefail

OC="${OC:-oc}"
fail() { printf 'preflight: %s\n' "$*" >&2; exit 1; }

command -v "$OC" >/dev/null 2>&1 || fail "oc is not on PATH. Set OC to the client binary."

if ! "$OC" whoami >/dev/null 2>&1; then
  fail "oc is not logged in. Run oc login before installing the pattern."
fi

version="$("$OC" get clusterversion version -o jsonpath='{.status.desired.version}' 2>/dev/null || true)"
if [[ -z "$version" ]]; then
  fail "could not read ClusterVersion.status.desired.version. The client needs permission to read clusterversion."
fi

python - "$version" <<'PY' || fail "OpenShift $version is older than 4.17. This pattern expects 4.17 or newer."
import sys
version = sys.argv[1].split("-", 1)[0]
parts = [int(p) for p in version.split(".")[:2]]
if parts < [4, 17]:
    sys.exit(1)
PY

if ! "$OC" get catalogsource redhat-operators -n openshift-marketplace >/dev/null 2>&1; then
  fail "CatalogSource redhat-operators was not found in openshift-marketplace."
fi

sc_count="$("$OC" get storageclass --no-headers 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${sc_count}" -lt 1 ]]; then
  fail "no StorageClass is installed. Postgres needs a StorageClass before install."
fi

domain="$("$OC" get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || true)"
if [[ -z "$domain" ]]; then
  fail "the cluster Ingress has no spec.domain. Certificate hostnames cannot be derived."
fi

printf 'preflight: OpenShift %s, Ingress domain %s, StorageClasses %s\n' "$version" "$domain" "$sc_count"
