# Exposing apps

We have working Gateways on our cluster(s), now we will create applications.

## 1. Create sample apps

We'll create simple apps based on nginx that we'll modify with a `configMap`.

the manifests look loke this.

```yaml

apiVersion: v1
kind: Namespace
metadata:
  name: gundam
spec: {}
status: {}
---
apiVersion: v1
kind: ConfigMap
metadata:
 name: index-html-barbatos
 namespace: gundam
data:
 index.html: |
   <html>
   <h1>Welcome to Gundam App </h1>
   </br>
   <h2>This is a demo to illustrate Gateway API </h2>
   <img src="https://imgs.search.brave.com/AfLpq5XX4tK6TtxoWLDbd_665qDaxYgPAJKBCxVl5aE/rs:fit:860:0:0:0/g:ce/aHR0cHM6Ly9tLm1l/ZGlhLWFtYXpvbi5j/b20vaW1hZ2VzL0kv/NjFyYkhlLTdCbEwu/anBn" />
   </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: barbatos
  name: barbatos
  namespace: gundam
spec:
  replicas: 3
  selector:
    matchLabels:
      app: barbatos
  template:
    metadata:
      labels:
        app: barbatos
    spec:
      volumes:
      - name: nginx-index-file
        configMap:
          name: index-html-barbatos
      containers:
      - image: nginx
        name: nginx
        volumeMounts:
        - name: nginx-index-file
          mountPath: /usr/share/nginx/html
        resources:
          requests:
            cpu: "50m"
            memory: "50Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
---
apiVersion: v1
kind: Service
metadata:
  namespace: gundam
  name: barbatossvc
  annotations:
    service.cilium.io/global: "true"
    service.cilium.io/shared: "true"
spec:
  type: ClusterIP
  ports:
  - port: 8090
    targetPort: 80
    protocol: TCP
  selector:
    app: barbatos    
---
apiVersion: v1
kind: ConfigMap
metadata:
 name: index-html-gundam
 namespace: gundam
data:
 index.html: |
   <html>
   <h1>Welcome to Gundam App 2</h1>
   </br>
   <h2>This is a demo to illustrate Gateway API </h2>
   <img src="https://www.previewsworld.com/SiteImage/FBCatalogImage/STL205689.jpg" />
   </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: gundamapp
  name: gundamapp
  namespace: gundam
spec:
  replicas: 3
  selector:
    matchLabels:
      app: gundamapp
  template:
    metadata:
      labels:
        app: gundamapp
    spec:
      volumes:
      - name: nginx-index-file
        configMap:
          name: index-html-gundam
      containers:
      - image: nginx
        name: nginx
        volumeMounts:
        - name: nginx-index-file
          mountPath: /usr/share/nginx/html
        resources:
          requests:
            cpu: "50m"
            memory: "50Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
---
apiVersion: v1
kind: Service
metadata:
  namespace: gundam
  name: gundamappsvc
  annotations:
    service.cilium.io/global: "true"
    service.cilium.io/shared: "true"
spec:
  type: ClusterIP
  ports:
  - port: 8090
    targetPort: 80
    protocol: TCP
  selector:
    app: gundamapp    
---

```

We should have 2 deployments and 2 services

```bash

df@df-2404lts:~$ k get deployments.apps -n gundam 
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
barbatos    3/3     3            3           12s
gundamapp   3/3     3            3           11s
df@df-2404lts:~$ k get svc -n gundam 
NAME           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
barbatossvc    ClusterIP   100.65.135.37   <none>        8090/TCP   2m11s
gundamappsvc   ClusterIP   100.65.50.185   <none>        8090/TCP   2m11s

```

Ok that was the easy part. Now to expose the apps, we'll use the `HTTPRoute`.

## 2. The HTTPRoute

### 2.1. HTTProute basics

Exposing an application is done with the http route. Details on this api object are available on the [gateway api documentation](https://gateway-api.sigs.k8s.io/reference/spec/#httproute).

A simple HTTPRoute configuration is as simple as what we have below.

The important part to remember for now are the `spec.parentRefs` which allow us to reference the Gateway used for the HTTPRoute, and the `spec.rules.backendRefs` which allows us to reference backend services.

```yaml

apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: gundam-httproute
  namespace: gundam
spec:
  parentRefs:
  - name: gundam-gw
  hostnames:
  #- "gundam.app.teknews.cloud"
  - "k8scalico1"
  rules:
  - backendRefs:
    - name: gundamappsvc
      port: 8080
      kind: Service

```

This manifest implies that we have a Gateway in the same namespace as our HTTPRoute, which is the same namespace as our app.

```yaml

apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gundam-gw
  namespace: gundam
spec:
  gatewayClassName: envoy-nodeport
  listeners:
  - protocol: HTTP
    port: 80
    name: gundam-gw
    allowedRoutes:
      namespaces:
        from: Same   

```

### 2.2. Managing path

Before going fully on this topics, let's step back a little.

With an Nginx Ingress controller, if we want to expose, let's say, 2 differents services on specific path, we create an ingress object as below.

```yaml

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-ingress-external
  namespace: demo
  labels:
    app: demo-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: external-ingress-nginx
  rules:
  - host: demoingress.app.teknews.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: aks-helloworld-one
            port:
              number: 80
      - path: /two
        pathType: Prefix
        backend:
          service:
            name: aks-helloworld-two
            port:
              number: 80

```

Assuming the underlying kubernetes services exist (and the associated apps), we would get something like this.

```bash

df@df-2404lts:~$ curl http://demoingress.app.teknews.cloud
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <link rel="stylesheet" type="text/css" href="/static/default.css">
    <title>Welcome to Azure Kubernetes Service (AKS) &#39;App One&#39; 1</title>

    <script language="JavaScript">
        function send(form){
        }
    </script>

</head>
<body>
    <div id="container">
        <form id="form" name="form" action="/"" method="post"><center>
        <div id="logo">Welcome to Azure Kubernetes Service (AKS) &#39;App One&#39; 1</div>
        <div id="space"></div>
        <img src="/static/acs.png" als="acs logo">
        <div id="form">      
        </div>
    </div>     
</body>
</html>

```

```bash

df@df-2404lts:~$ curl http://demoingress.app.teknews.cloud/two
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <link rel="stylesheet" type="text/css" href="/static/default.css">
    <title>Welcome to Azure Kubernetes Service (AKS) &#39;App two&#39; 2</title>

    <script language="JavaScript">
        function send(form){
        }
    </script>

</head>
<body>
    <div id="container">
        <form id="form" name="form" action="/"" method="post"><center>
        <div id="logo">Welcome to Azure Kubernetes Service (AKS) &#39;App two&#39; 2</div>
        <div id="space"></div>
        <img src="/static/acs.png" als="acs logo">
        <div id="form">      
        </div>
    </div>     
</body>
</html>

```


But the really interesting part here, is the annotation `nginx.ingress.kubernetes.io/rewrite-target: /` which, as it implies, rewrite the paths on the ingress to the`/` path of our apps.

Ok time to try this with the httproute.

We want to expose, let's say, the barbatos apps to our http route, so we add an additional rule in the `spec.rules` section : 

```yaml

  - backendRefs:
    - name: barbatossvc
      port: 8090
      kind: Service
    matches:
    - path:
        type: PathPrefix
        value: /barbatos

```

But it does not work like this. It would be too easy.

```bash

df@df-2404lts:~/Documents/myrepo/ingress_to_gapi_workshop$ curl -i -X GET http://k8scalico1:32293/barbatos
HTTP/1.1 404 Not Found
server: nginx/1.31.0
date: Fri, 15 May 2026 15:29:08 GMT
content-type: text/html
content-length: 153

<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx/1.31.0</center>
</body>
</html>

```

Actually, the request goes to an unexisting path, as we can see on the deployment logs.

```bash

df@df-2404lts:~$ k $cal logs -n gundam deployments/barbatos 
Found 3 pods, using pod/barbatos-7b787b5dc4-cwfb5
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2026/05/15 14:44:13 [notice] 1#1: using the "epoll" event method
2026/05/15 14:44:13 [notice] 1#1: nginx/1.31.0
2026/05/15 14:44:13 [notice] 1#1: built by gcc 14.2.0 (Debian 14.2.0-19) 
2026/05/15 14:44:13 [notice] 1#1: OS: Linux 6.8.0-64-generic
2026/05/15 14:44:13 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1024:524288
2026/05/15 14:44:13 [notice] 1#1: start worker processes
2026/05/15 14:44:13 [notice] 1#1: start worker process 29
2026/05/15 14:44:13 [notice] 1#1: start worker process 30
2026/05/15 16:17:55 [error] 29#29: *1 open() "/usr/share/nginx/html/barbatos" failed (2: No such file or directory), client: 100.64.38.221, server: localhost, request: "GET /barbatos HTTP/1.1", host: "k8scalico1:32293"
100.64.38.221 - - [15/May/2026:16:17:55 +0000] "GET /barbatos HTTP/1.1" 404 153 "-" "curl/8.5.0" "192.168.56.1"

```

Let's look at the httproute object to find how it can be done. 

In the `spec.rules` section, we already added a matches sections, which contain a path. From the [documentation](https://gateway-api.sigs.k8s.io/reference/spec/#httproutefiltertype), we can see that a `filters` section can be added. 

Specifically, we can use the `URLRewrite` type 

| Field | Description | Default | Validation |
|-|-|-|-|
| `type` | Type defines the type of path modifier. | Enum: [ReplaceFullPath ReplacePrefixMatch] |
| `replaceFullPath` | Specifies the value with which to replace the full path of a request during a rewrite or redirect. || MaxLength: 1024 |
| `replacePrefixMatch` | Specifies the value with which to replace the prefix match of a request during a rewrite or redirect. |  | MaxLength: 1024 |

And then specify the appropriate properties to modify the path:

- a `type`, which accept ReplaceFullPath and ReplacePrefixMatch
- the `replacePrefixMatch` which in this case will be `/` to replace the prefix on the http route with the `/` path on the container.

Now we can update the `HTTPRoute`.

```yaml

apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: gundam-httproute
  namespace: gundam
spec:
  parentRefs:
  - name: gundam-gw
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

And now it's working as expected.

```bash

df@df-2404lts:~$ curl -i -X GET http://k8scalico1:32293/barbatos
HTTP/1.1 200 OK
server: nginx/1.31.0
date: Fri, 15 May 2026 16:24:05 GMT
content-type: text/html
content-length: 288
last-modified: Fri, 15 May 2026 15:16:40 GMT
etag: "6a0738d8-120"
accept-ranges: bytes

<html>
<h1>Welcome to Gundam App 2</h1>
</br>
<h2>This is a demo to illustrate Gateway API </h2>
<img src="https://imgs.search.brave.com/AfLpq5XX4tK6TtxoWLDbd_665qDaxYgPAJKBCxVl5aE/rs:fit:860:0:0:0/g:ce/aHR0cHM6Ly9tLm1l/ZGlhLWFtYXpvbi5j/b20vaW1hZ2VzL0kv/NjFyYkhlLTdCbEwu/anBn" />
</html>

```

That's all for basic path management. There's a lot more with options to filter depending on header or stuff like that.

For now, we want to see if we can manage traffic weight.

### 2.3. Managing weight


The http route has a native capability of weight management. 

Again, from the documentation, we can find the spec.rules.backendRefs.weight:

| Field | Description | Default | Validation |
|-|-|-|-|
| `weight` | Weight specifies the proportion of requests forwarded to the referenced backend. This is computed as weight/(sum of all weights in this BackendRefs list). | 1 | Max 1e+06 </br> Min 0 |

Transposed in an http route, it looks like this:

```yaml

apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: gundamsplit
  namespace: gundam
spec:
  parentRefs:
  - name: gundamsplit-gw
  hostnames:
  - "k8scalico1"
  rules:
  - backendRefs:
    - kind: Service
      name: evasvc
      port: 8091
      weight: 50
    - kind: Service
      name: exiasvc
      port: 8092
      weight: 50       

```

With the weight configured like this, we shooudl get an even traffic.

```bash

df@df-2404lts:~$ while true; do curl -s -k "http://k8scalico1:31481" >> curlresponses.txt ;done
^C
df@df-2404lts:~$ cat curlresponses.txt | grep -i exia | wc -l
351
df@df-2404lts:~$ cat curlresponses.txt | grep -i EVA | wc -l
352

```

If we change the weight to 90/10, we should have a different result.

```yaml

  rules:
  - backendRefs:
    - kind: Service
      name: evasvc
      port: 8091
      weight: 10
    - kind: Service
      name: exiasvc
      port: 8092
      weight: 90   

```

```bash

df@df-2404lts:~$ cat curlresponses.txt | grep -i EVA | wc -l
90
df@df-2404lts:~$ cat curlresponses.txt | grep -i exia | wc -l
808

```

Now we'll have a look at the TLS management.

## 3. TLS management basics

