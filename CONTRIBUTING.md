# Contributing

Issues and pull requests are welcome on https://github.com/maximilianoPizarro/rhbk-cert.

- Do not commit `values-secret.yaml`, kubeconfigs, tokens, or cloud credentials.
- Keep product names as shipped by Red Hat: Connectivity Link, not Kuadrant, and Service Mesh, not Istio. The API group `kuadrant.io` is the CRD group and can be named when a manifest requires it.
- Documentation changes belong in both `docs/index.html` and `docs/es/index.html`.
- Chart changes should keep `helm lint` clean. `make install` is not required for a documentation pull request.
