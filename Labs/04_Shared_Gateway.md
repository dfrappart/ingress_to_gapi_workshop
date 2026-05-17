# Shared Gateway considerations

We go back once again to the Role oriented model of the Gateway API.

To summarize, We have the following.

| API Object | Owner |
|-|-|
| `GatewayClass`| Infrastructure team |
| `Gateway` | Cluster team|
| `HTTPRoute` or `gRPCRoute`...| Dev team |

We'll now try to illustrate the sahred gateway scenario, with the same apps as before, but a centrally managed Gateway that will live in its own namespace, and another dedicated namespace for the certicates.

Ok, now time to create stuffs.

## 1. Namespaces

We want to follow the segration of duty available in the Gateway API, so we have one namespace for the Gateway; one for the apps and the HTTPRoute, and a third one for the certificates

```yaml

apiVersion: v1
kind: Namespace
metadata:
  name: certificates
spec: {}
status: {}
---
apiVersion: v1
kind: Namespace
metadata:
  name: shared-gw
spec: {}
status: {}
---
apiVersion: v1
kind: Namespace
metadata:
  name: gundam
spec: {}
status: {}

```
## 2. The Certificate

The certificate creation process is exactly the same as before, but this time, we use a dedicated namespace for the secret. So we have something like this

```bash

kubectl create secret tls gundamapp-tls --namespace certificates --key <path_to_key_file> --cert <path_to_cert_file>

```

We also need to authorize the use of the secrtets by the Gateway from its namespace. That's what the referenceGrant is for.

```yaml

apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-shared-gw-to-ref-secrets
  namespace: certificates
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: Gateway
    namespace: shared-gw
  to:
  - group: ""
    kind: Secret  

```

## 3. The Gateway

The Gateway can be created. It has to refer the certificate secret, in the certificates namespace.

```yaml

apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shared-gw-tls
  namespace: shared-gw
spec:
  gatewayClassName: envoy-nodeport
  listeners:
  - protocol: HTTPS
    port: 443
    name: shared-gw-tls
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchExpressions:
          - { key: kubernetes.io/metadata.name, operator: In, values: [gundam,demoapp] }
    tls:
      certificateRefs:
      - kind: Secret
        group: ""
        name: gundamapp-tls
        namespace: certificates

```

We'll notice the `allowedRoutes` section where we specify which namespaces are allowed.

Up until now, we had allowedRoutes.namespaces.from with a value set to same. It's possible to set it to all, but in the sample, we only allow a subset of namespaces.
It is highly likely that the cluster team would be responsible to manage the shared Gateway, and in this case, which namespaces are allowed to use it. 

## 4. The HTTPRoute

For the app, nothing change really, If we need an HTTPRoute to expose the app, then the dev team can create it in the app namespace

```yaml

apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: gundam-httproute-with-shared-gw
  namespace: gundam
spec:
  parentRefs:
  - name: shared-gw-tls
    namespace: shared-gw
  hostnames:
  #- "gundam.app.teknews.cloud"
  - "k8scalico1"
  rules:
  - backendRefs:
    - name: gundamappsvc
      port: 8080
      kind: Service
  - backendRefs:
    - name: barbatossvc
      port: 8090
      kind: Service
    matches:
    - path:
        type: PathPrefix
        value: /barbatos
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /

```

Nothing big here.

However, if we compare to the Ingress, some may notice that the tls is managed on a different scope.

The sample taken from the documentation illustrate this point.

```yaml

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-example-ingress
spec:
  tls:
  - hosts:
      - https-example.foo.com
    secretName: testsecret-tls
  rules:
  - host: https-example.foo.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: service1
            port:
              number: 80


```

Which means that the Gateway API model takes capabilities tomanage TLS from the Dev and put it to the cluster admin.
That's a change to consider... OR not.

There is a relatively new object that has been added to the Gateway API portfolio that can be used to let TLS be managed at the app dev level. 

Enter the listener set.

## 5. The listenerset

Coming when I'll make it works