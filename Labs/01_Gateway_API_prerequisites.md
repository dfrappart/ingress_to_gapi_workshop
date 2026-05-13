# Gateway API Prerequisites

In this first Lab, we want to prepare the use of a Gateway API.

We'll start with a very higl level overview of Ingress, and then we'll start talking about Gateway API. 

This'll allow us to make some comparison.

## 1. Very short review of Ingress concepts

By default, network exposition is decorralated from the applications that run inside pods.
That's kind of the micro-service (and thus k8s) approach, loose coupling and stuff...

Natively, Kubernetes includes the service which allows to map application to an fqdn that is persistant over time (which may not be the case for the pods, that may die, restart, be recreated, updated... and thus have an IP change).

However, the kubernetes service is only a layer 4 network option, which means no layer 7 so noi http awareness.

That's where Ingress came into play.

Starting from kubernetes 1.18, the Ingress is GA (and again for version 1.22).

What it brings to the table: A way to manage layver 7 management with the ingress API object which allow us to associate kubernetes service to http path (to keep things simple, I mentioned It would be very high level right?).

The architecture is described in the [dedicated kubernetes documentation section](https://kubernetes.io/docs/concepts/services-networking/ingress/)

The ingress define routing rules to services that are associated with pods. 

It's also managing a load balancer, outside of the cluster, so that external access caan be granted.

![illustration1](/assets/ingress.png)

A sample yaml , taken from the kubernetes doc, looks like this.

```yaml

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minimal-ingress
spec:
  ingressClassName: nginx-example
  rules:
  - http:
      paths:
      - path: /testpath
        pathType: Prefix
        backend:
          service:
            name: test
            port:
              number: 80


```

Taking the assumption that a `service` named **test** exist in the **default** `namespace`, the `ingress` named **minimal-ingress**, also in the **default** `namespace`, define a routing rule to the `service` using the */testpath* path.

The external load balancer represented on the schema is define not on the ingress definition, as one can see (or not see &#129300;) but rather thorugh the ingress controller that is installed on the cluster.

Which allow us to reach the second statement of the ingress: It does require a specific installation, from a 3rd party provider (like other things in kubernetes, sucvh as the CNI for example).

Informations on the ingress controllers and the different providers are also available in the [documentation](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/).

Ok, now let's switch to the Gateway API, because that's kind of the main topic of this.


## 1. Gateway API concepts

Behind the project are some motivations, due to the limitations that appeared during the ingress lifecycle. Among those we could list:

- Too Simplistic: Ingress was designed primarily for HTTP/HTTPS routing and lacks support for advanced use cases (e.g., TCP/UDP, gRPC, WebSockets, or custom protocols).
- Limited Extensibility: Ingress relies heavily on annotations for extended functionality, leading to vendor lock-in and inconsistent implementations across controllers (e.g., NGINX, Traefik, ALB).
- No Standard for Advanced Features: Features like retries, timeouts, request mirroring, or cross-namespace references were either unsupported or implemented inconsistently.
- Role-Based Separation Missing: Ingress does not clearly separate concerns between infrastructure operators (who manage load balancers) and application developers (who define routing rules).

We'll see that some of those are well adressed, some other maybe a little less well.

As per the documentation, the Gateway API embrace a role-oriented design.

![illustration2](/assets/resource-model.png)

Which address the 4th point of the previous list.

We'll see in the coming parts that we can address the first point through the use of CRDs that are made avaiablae and defined independantly from the Gateway API provider.
If you ever wondered, we still need to install stuffs on our cluster to use the Gateway API capabilities, and as exprected we have a quite big list of providers.

We'll see a bit of the cross-namespace capablities, which also work with a CRD, figures...

And last but not least, we'll have a look at how we address the change from annotations to accomplish some behaviour to something else, and sometime not &#128517;

On elast thing about the concepts, since we mentioned the providers of Gateway API implementation, it's interesting to note that there is a level of conformance that is defined for those providers:

- Conformant implementations have submitted at least one conformance report that passes for all core conformance tests for one combination of Route type and profile (For example, Gateway + HTTPRoute) and clazimed extended features.
- Partially conformant implementations have submitted conformance report passing some of the tests to be conformant for one of the three most regent Gateway API releases.
- Stale implementations may not be actively developped and either have to satisfy the partially conformant requirements (or conformant) or to be removed from the list of providers.

Among the conformant providers, we could list Istio, Cilium, Trafik proxy or Nginx Gateway Fabric.

Partially conformant providers include Envoy Gateway and AWS Load Balancer Controller.

An interesting exemple of stale provider is Azure Application Gateway for container.

In the coming labs, we'll use mostly Cilium and Envoy Gateway. Now we'll have alook at what we need to start using the Gateway API.

## 2. Gateway API requirements

Apart from a running kubernetes cluster, in a supported version, we need to have the CRDs that define the Gateway API objects.
From my point of view, it is still quite strange that a new standard for managing applications exposition relies on CRDs that we need to install, and update but well, what can I say...

Those CRDs define the objects that we'll dive into during this workshop. Below is the list of those CRDs for the Standard API implementation (as opposite to the Experimental one)

| CRD | Usage |
|-|-|
| `GatewayClass` | `GatewayClass` describes a class of Gateways available to the user for creating Gateway resources. |
| `Gateway` | `Gateway` represents an instance of a service-traffic handling infrastructure by binding Listeners to a set of IP addresses. |
| `HTTPRoute` | `HTTPRoute` provides a way to route HTTP requests. This includes the capability to match requests by hostname, path, header, or query param. |
| `GRPCRoute` | `GRPCRoute` provides a way to route gRPC requests. This includes the capability to match requests by hostname, gRPC service, gRPC method, or HTTP/2 header. |
| `TLSRoute` | The `TLSRoute` resource is similar to TCPRoute, but can be configured to match against TLS-specific metadata. This allows more flexibility in matching streams for a given TLS listener. |
| `ReferenceGrant` | `ReferenceGrant` identifies kinds of resources in other namespaces that are trusted to reference the specified kinds of resources in the same namespace as the policy. |
| `ListenerSet` | `ListenerSet` defines a set of additional listeners to attach to an existing Gateway. This resource provides a mechanism to merge multiple listeners into a single Gateway. |
| `BackendTLSPolicy` | `BackendTLSPolicy` provides a way to configure how a Gateway connects to a Backend via TLS.|

Installing those CRDs can be done from a `kubectl` command as defined on the [github release page](https://github.com/kubernetes-sigs/gateway-api/releases).

```bash

kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/download/monthly-2026.05/monthly-2026.05-install.yaml

```

Interestingly, some providers publish a dedicated helm chart to install those CRDs (among other things). Envoy is one of those providers and we can install the CRDs by following the [provided instructions](https://gateway.envoyproxy.io/docs/install/install-helm/).

```bash

helm template eg oci://docker.io/envoyproxy/gateway-crds-helm \
  --version v1.7.2 \
  --set crds.gatewayAPI.enabled=true \
  --set crds.gatewayAPI.channel=standard \
  --set crds.envoyGateway.enabled=true \
  | kubectl apply --server-side -f -

```

## 3. Installing Gateway API