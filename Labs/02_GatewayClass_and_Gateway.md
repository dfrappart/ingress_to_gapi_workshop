# GatewayClass and Gateway

Now that we have the prerequisites installed on our cluster, we can start using the Gateway API, or at least the first API objects. But first, let's look back to the Ingress stuffs.

## 1. Ingress Controller rapid review

In the p^revious section, we reviewed (shortly) how the ingress worked through a simple schema.

It's still worth our time to have a look at an existing installation of an Ingress controller.

In our case, we'll take the most simple exemple with a basic installation of the Nginx Ingress Controller, which by the way, was archived during last kubecon EU in march 2026.

That being said, an installation can be done with the following command.

```bash

#!/bin/sh

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort

```

After the installation, inspecting the resulting objects would show us the existence of a NodePort service in this case. This same service is the one that is used for all of our ingress object.

```bash

vagrant@k8ssingle1:~$ k get service -n ingress-nginx 
NAME                                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             NodePort    100.65.27.244    <none>        80:30375/TCP,443:31083/TCP   28s
ingress-nginx-controller-admission   ClusterIP   100.65.208.243   <none>        443/TCP                      28s

```

To have more than one kubernetes service serving our Ingresses object, we would need more than one controller. 
To do so, and also avoid a potential competition between controller, we need to specify an IngressClass.

Currently, we have one.

```bash

vagrant@k8ssingle1:~$ k get ingressclasses.networking.k8s.io 
NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       4m8s

```

By specifying the parameter `controller.ingressClassResource.name` in our installation, we can get a second ingress controller with its own IngressClass

```bash

#!/bin/sh

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx-again ingress-nginx/ingress-nginx \
  --namespace ingress-nginx-again \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.ingressClassResource.name="another-nginx"

```

```bash

vagrant@k8ssingle1:~$ k get ingressclasses.networking.k8s.io 
NAME            CONTROLLER             PARAMETERS   AGE
another-nginx   k8s.io/ingress-nginx   <none>       21s
nginx           k8s.io/ingress-nginx   <none>       12m
vagrant@k8ssingle1:~$ k get service -n ingress-nginx-again 
NAME                                       TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-again-controller             NodePort    100.65.67.209    <none>        80:31360/TCP,443:31547/TCP   34s
ingress-nginx-again-controller-admission   ClusterIP   100.65.119.156   <none>        443/TCP                      34s

```

In a Cloud based environment, we could leverage ingress classes to differentiate different ingress controller according to the traffic. One for Public traffic, one for private. Then, by passing annotations specific to the Cloud provider, we could  get either a public `LoadBalancer`, or an internal one.

For example, such annotations for Azure would be like this.

```yaml

annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"

```

We'll keep that in mind.

Ok, now back to the Gateway API.

## 2. The GatewayClass

AS we mentionned, the Gateway API is designed with a segregation of duty consideration, and we have different personnas that should do different stuff.

It is planned that we can have more than one `Gateway` (Yes, we did not detailed what it is yet, be patient &#128541;), and we also have something called the `GatewayClass` that is defined in the Gateway API CRDs.

As a matter of facts, with our cilium based cluster, we do have a default `GatewayClass`

```bash

vagrant@k8ssingle1:~$ k get gatewayclasses.gateway.networking.k8s.io 
NAME     CONTROLLER                     ACCEPTED   AGE
cilium   io.cilium/gateway-controller   True       25m

```

```bash

vagrant@k8ssingle1:~$ k describe gatewayclasses.gateway.networking.k8s.io cilium 
Name:         cilium
Namespace:    
Labels:       app.kubernetes.io/managed-by=Helm
Annotations:  meta.helm.sh/release-name: cilium
              meta.helm.sh/release-namespace: kube-system
API Version:  gateway.networking.k8s.io/v1
Kind:         GatewayClass
Metadata:
  Creation Timestamp:  2026-05-14T21:05:11Z
  Generation:          1
  Resource Version:    927
  UID:                 ca0b2f5d-2258-4b4b-8320-1fdc01c4cea4
Spec:
  Controller Name:  io.cilium/gateway-controller
  Description:      The default Cilium GatewayClass
Status:
  Conditions:
    Last Transition Time:  2026-05-14T21:05:39Z
    Message:               Valid GatewayClass
    Observed Generation:   1
    Reason:                Accepted
    Status:                True
    Type:                  Accepted
  Supported Features:
    Name:  BackendTLSPolicySANValidation
    Name:  GRPCRoute
    Name:  GRPCRouteNamedRouteRule
    Name:  Gateway
    Name:  GatewayAddressEmpty
    Name:  GatewayHTTPListenerIsolation
    Name:  GatewayInfrastructurePropagation
    Name:  GatewayPort8080
    Name:  GatewayStaticAddresses
    Name:  HTTPRoute
    Name:  HTTPRouteBackendProtocolH2C
    Name:  HTTPRouteBackendProtocolWebSocket
    Name:  HTTPRouteBackendRequestHeaderModification
    Name:  HTTPRouteBackendTimeout
    Name:  HTTPRouteDestinationPortMatching
    Name:  HTTPRouteHostRewrite
    Name:  HTTPRouteMethodMatching
    Name:  HTTPRouteNamedRouteRule
    Name:  HTTPRoutePathRedirect
    Name:  HTTPRoutePathRewrite
    Name:  HTTPRoutePortRedirect
    Name:  HTTPRouteQueryParamMatching
    Name:  HTTPRouteRequestMirror
    Name:  HTTPRouteRequestMultipleMirrors
    Name:  HTTPRouteRequestPercentageMirror
    Name:  HTTPRouteRequestTimeout
    Name:  HTTPRouteResponseHeaderModification
    Name:  HTTPRouteSchemeRedirect
    Name:  Mesh
    Name:  MeshClusterIPMatching
    Name:  MeshHTTPRouteBackendRequestHeaderModification
    Name:  MeshHTTPRouteNamedRouteRule
    Name:  MeshHTTPRouteQueryParamMatching
    Name:  MeshHTTPRouteRedirectPath
    Name:  MeshHTTPRouteRedirectPort
    Name:  MeshHTTPRouteRewritePath
    Name:  MeshHTTPRouteSchemeRedirect
    Name:  ReferenceGrant
    Name:  TLSRoute
Events:    <none>

```

Note that the `GatewayClass` status should display a `conditions` section  with `type: Accepted` and `status: "True"`. If it does not, then it's trouble.

Also, as we had on the role oriented schema, GatewayClass is more on the Infrastructure Provider level, so It would make sense to define a GatewayClass for the kind of traffic right.

![illustration3](/assets/gapiresourcemodel.png)

If we look at the GatewayClass API Object, we get this.

| Field | Description | Value |
|-|-|-|
| apiVersion | A string defining as usual the API version. | `gateway.networking.k8s.io/v1` |
| kind | Another string defining the object type. | `GatewayClass`|
| metadata | The metadata section contains information related to the identification of the object, such as the name||
| spec | The spec section contains information related to the object specifications | |


And the following sdub parameters in the `spec` section.

| Field | Description | Value |
|-|-|-|
| controllerName | A string defining the controller name | Specific to the Gateway API provider. For Cilium `io.cilium/gateway-controller` |
| parametersRef | Another sub-section to further define the gateway class, specific to the controller | |
| description | A string that allow to describe the class ||

The `parametersRef` sub-section is used for provider specific configuration and can refers either to a CRD or a configmap.
In the case of Cilium, there is indeed a CRD called `CiliumGatewayClassConfig` that can be used to feed specific parameters to the `parametersRef` section.

It means that the more custom stuff for GatewayClass is kind of delegated to the providers.

Note that for Envoy Gateway, the other provider that we will use, there is also another custom CRD called the `EnvoyProxy`.

We'll have a look at that later.

For now, we'll keep in mind that there is no native way to define either the kind of service that we want to use in our GatewayClass, nor any mean to pass potential cloud specific annotations.

Now we look to the Gateway.

## 3. The Gateway

The `GatewayClass` is a requirement so that we can define a `Gateway`, but it's the latter that is responsible to provide the mean to expose the apps.

While we did have a default `GatewayClass`earlier, there is no default `Gateway`.

```bash

vagrant@k8ssingle1:~$ k get gateways.gateway.networking.k8s.io -A
No resources found

```

Also, while the `GatewayClass` is cluster-wide, the `Gateway` is namespaced.

```bash

vagrant@k8ssingle1:~$ k api-resources --api-group gateway.networking.k8s.io
NAME                 SHORTNAMES   APIVERSION                          NAMESPACED   KIND
backendtlspolicies   btlspolicy   gateway.networking.k8s.io/v1        true         BackendTLSPolicy
gatewayclasses       gc           gateway.networking.k8s.io/v1        false        GatewayClass
gateways             gtw          gateway.networking.k8s.io/v1        true         Gateway
grpcroutes                        gateway.networking.k8s.io/v1        true         GRPCRoute
httproutes                        gateway.networking.k8s.io/v1        true         HTTPRoute
referencegrants      refgrant     gateway.networking.k8s.io/v1beta1   true         ReferenceGrant

```

As displayed on the below schema, the gateway is the first element that we access to when we try to reach an app on a kubernetes environment.

![illustration4](/assets/gateway.png)

With this, and the role based organization schema, it's clear that we diverge from the ingress concepts.

Indeed, the ingress controller defined an ingress class and a unique entry point (A kubernetes service as we said already) while the `GatewayClass` can be parent to many different gateways (Each with its own Kubernetes service but we're about to see this).

Below is a sample gateway definition, using the default cilium gateway class.

```yaml

apiVersion: v1
kind: Namespace
metadata:
  name: samplegw
spec: {}
status: {}
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: test-gw
  namespace: samplegw
spec:
  gatewayClassName: cilium
  listeners:
  - protocol: HTTP
    port: 80
    name: test-gw
    allowedRoutes:
      namespaces:
        from: Same 

```

While we can apply those manifest, we will get a `PROGRAMMED` with `False` value

```bash

vagrant@k8ssingle1:~$ k get gateway -n samplegw 
NAME      CLASS    ADDRESS   PROGRAMMED   AGE
test-gw   cilium             False        3m41s

```


```bash

vagrant@k8ssingle1:~$ k get -n samplegw gateway test-gw -o json |jq '.status.conditions'
[
  {
    "lastTransitionTime": "2026-05-14T22:17:05Z",
    "message": "Gateway successfully scheduled",
    "observedGeneration": 1,
    "reason": "Accepted",
    "status": "True",
    "type": "Accepted"
  },
  {
    "lastTransitionTime": "2026-05-14T22:17:05Z",
    "message": "Gateway waiting for address",
    "observedGeneration": 1,
    "reason": "AddressNotAssigned",
    "status": "False",
    "type": "Programmed"
  }
]

```

That's because we cannot get an IP on this cluster. Looking into the `samplegw` namespace, we can find the underlying service of our `Gateway` in a pending status, because, as a `LoadBalancer` kind, it's expecting the Platform provider to provide a ... `LoadBalancer`

```bash

vagrant@k8ssingle1:~$ k get service -n samplegw 
NAME                     TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
cilium-gateway-test-gw   LoadBalancer   100.65.142.110   <pending>     80:30180/TCP   4m59s

```

In doubt, we could check the `metadata.ownerReferences` and see that the service does refer to the gateway.

```bash

vagrant@k8ssingle1:~$ k get service -n samplegw cilium-gateway-test-gw -o json |jq .metadata.ownerReferences
[
  {
    "apiVersion": "gateway.networking.k8s.io/v1",
    "controller": true,
    "kind": "Gateway",
    "name": "test-gw",
    "uid": "238a4fad-ca94-4ada-a100-f70a426f3a3d"
  }
]

```

Note that if we try this on a cluster running in a cloud environment, it should work fine.

Ok, let's customize our `Gateway` through the `GatewayClass` configuration.

## 4. Customizing the GatewayClass and the Gateway

We mentionned earlier that the `parametersRef` can be used to reference a CRD specific to the provider.

Typically, with cilium, we would use `CiliumGatewayClassConfig` in which we can specify the service type.

```yaml

apiVersion: cilium.io/v2alpha1
kind: CiliumGatewayClassConfig
metadata:
  name: gateway-class-config
  namespace: samplegw
spec:
  service:
    type: NodePort    

```

We have the same kind of CRD for envoy gateway.

```yaml

apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: nodeport-proxy
  namespace: envoy-gateway-system
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyService:
        type: NodePort

```