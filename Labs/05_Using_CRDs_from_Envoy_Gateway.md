# Using CRDs from Envoy Gateway

In this last session, we want to take a look at the additional CRDs of Envoy Gateway.

The funny thing with the API Gateay is that it aims to standardize how apps can be exposed.
The lack of this with the different Ingress Controller provider was kind of visible. Either we had custom annotations, or CRDs.

We saw that there now a standard (and experimental) set of CRDs for exposing the apps with the Gatezway API.

But it does not mean that there is no additional capabilities that are though about and provider by... provider.

Hence additional CRDs.

Remember, we install Gateway API for Envoy with 2 helm charts. One for the CRDs, and one for the Gateway provider itself.

```bash

helm template eg oci://docker.io/envoyproxy/gateway-crds-helm \
  --version v1.7.2 \
  --set crds.gatewayAPI.enabled=false \
  --set crds.envoyGateway.enabled=true \
  | kubectl apply --server-side -f -

```

The `--set crds.envoyGateway.enabled=true` allows us to install the Envoy specific CRDs.

We can list the available CRDs once we have installed those.

```bash

vagrant@k8ssingle2:~$ k get crd |grep envoyproxy
backends.gateway.envoyproxy.io                          2026-05-17T14:09:37Z
backendtrafficpolicies.gateway.envoyproxy.io            2026-05-17T14:09:37Z
clienttrafficpolicies.gateway.envoyproxy.io             2026-05-17T14:09:37Z
envoyextensionpolicies.gateway.envoyproxy.io            2026-05-17T14:09:37Z
envoypatchpolicies.gateway.envoyproxy.io                2026-05-17T14:09:37Z
envoyproxies.gateway.envoyproxy.io                      2026-05-17T14:09:37Z
httproutefilters.gateway.envoyproxy.io                  2026-05-17T14:09:37Z
securitypolicies.gateway.envoyproxy.io                  2026-05-17T14:09:38Z

```

There are quite a lot. We'll take a look only at the `SecurityPolicy`.

## Using the Security policy for oidc authentication

As per the [documentation](https://gateway.envoyproxy.io/docs/tasks/security/oidc/), we can configure oidc authentication with a security policy.

To perform this, we'll need some kubernetes resources, obviously, but also an oidc authentication compatible system.

In this case we'll use Entra Id as our provider.

But first the kubernetes resources

First we need to define an HTTPRoute using a public Gateway. We saw how to do that, so we'll reuse some of those.

Then we'll define a `SecurityPolicy`. It will look like this.

```yaml

---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: oidc-envoy-app1-security-policy
  namespace: gundam
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: demo-httproute
  oidc:
    provider:
      issuer: "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
    clientID: "00000000-0000-0000-0000-000000000000"
    clientSecret:
      name: "envoy-app-client-secret"
    redirectURL: "https://app1.app.teknews.cloud/oauth2/callback"
    logoutPath: "/logout"

```

Note that it refers to an Opaque `Secret` which is define like this.

```yaml

---
apiVersion: v1
data:
  client-secret: <Secret_Value>
kind: Secret
metadata:
  creationTimestamp: null
  name: envoy-app-client-secret
  namespace: gundam

```

The secret value refers to the secret define on the Entra Id Application registration that we define for OIDC Auth with Entra Id.

![illustration4](/assets/envoy004.png)

We need also to define some authorization on the Graph API, so that the app registration can read some informations on Entra Id.

![illustration5](/assets/envoy005.png)


And last we need to define some urls.

![illustration6](/assets/envoy006.png)

If everything works correctly, we should get an authentication mire before accessing the demo app.

```bash

df@df-2404lts:~$ curl -k -i -X GET https://app1.app.teknews.cloud
HTTP/2 302 
set-cookie: OauthNonce-97a9498a=f0dec3de0a392bae.gCNoymoqJvP2NUQjWm+zqQV3TLG+UTP+rVwC/fAzyp8=;path=/;Max-Age=600;secure;HttpOnly
set-cookie: CodeVerifier=t039-RkcWijBpDobHuMsVKc1ShDGm8BAQdZEIUn5ZuLbpvVfptaFWKn75xCvNJTExQ_btF3YIkWiNSM2AKnaDA;path=/;Max-Age=600;secure;HttpOnly
location: https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/oauth2/v2.0/authorize?client_id=00000000-0000-0000-0000-000000000000&code_challenge=Xz1VjTI7vFg642-boa3szOp854pxo3L3AnUmd7OT_Fc&code_challenge_method=S256&redirect_uri=https%3A%2F%2Fapp1.app.teknews.cloud%2Foauth2%2Fcallback&response_type=code&scope=openid&state=eyJ1cmwiOiJodHRwczovL2FwcDEuYXBwLnRla25ld3MuY2xvdWQvIiwiY3NyZl90b2tlbiI6ImYwZGVjM2RlMGEzOTJiYWUuZ0NOb3ltb3FKdlAyTlVRaldtK3pxUVYzVExHK1VUUCtyVndDL2ZBenlwOD0ifQ
date: Thu, 29 Jan 2026 15:33:48 GMT


```

![illustration7](/assets/envoy007.png)

![illustration8](/assets/envoy008.png)