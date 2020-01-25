---
layout: post
comments: true
title: Knative development without Istio
description: >-
  Exploration of the alternatives offered by Knative Serving to function without Istio, a robust but resource-intensive
  service mesh solution that takes its toll on developers' machines.
image: knative-without-istio/post.jpg
tldr: >-
  Knative Serving's API allows for swapping Istio for another, possibly leaner, ingress implementation. Gloo and Contour
  are two alternatives among others.
---

<span class="dropcap">W</span>hen I entered the magical world of [Knative][kn-landing] last year, I gulped after
discovering the wall of YAML composing the project's release. One `kubectl apply` later, my helpless MacBook Air was on
its knees, unable to handle the army of services I was throwing at it, until the first occurrence of this fatal
scheduler event ultimately occurred: _"No nodes are available that match all of the following predicates: Insufficient
memory"_.

It turns out Knative itself is relatively lean. The culprit, against my expectations, was [Istio][istio-landing] and its
greedy [_Pilot_ component][istio-pilot-req]. If you clicked that last link, you will have noticed the gigabyte-range
memory requirement per _Pilot_ instance which, ironically, applies to "small" setups. Throw a _second_ instance into the
mix, as configured in the default Istio setup, and you end up with half of your average laptop's memory allocated to a
software solution which sole purpose is to back the actual platform you were trying to deploy. Aouch.

[kn-landing]: https://knative.dev/
[istio-landing]: https://istio.io
[istio-pilot-req]: https://github.com/istio/istio/blob/release-1.3/install/kubernetes/helm/istio/charts/pilot/values.yaml#L19-L23

## Why Istio?

A fair question to ask. I may have given Istio a bad rap in my introduction but, truth be told, Istio is currently [the
most versatile service mesh for Kubernetes][service-mesh-comparison]. The way Istio manages to deliver a secure and
homogeneous service mesh for containerized workloads together with powerful telemetry features on top of almost any
protocol is quite magical. Knative was designed from the ground up to be run side by side with Istio, and using Istio
provides a guarantee that all the bleeding edge Knative features will work in your environment.

But for development purposes, cost efficiency, speed and operability generally outweighs the benefits provided by a
full-fledged service mesh, especially when the focus is not network interoperability or security. At the edge, an API
gateway should be sufficient and, within the cluster, Kubernetes' internal network should have us covered. Let's find
out what Knative truly requires in order to be able to serve north-south traffic.

[service-mesh-comparison]: https://platform9.com/blog/kubernetes-service-mesh-a-comparison-of-istio-linkerd-and-consul/

## Knative's expectations

The [runtime contract for Knative Serving][contract-conn] defines prerequisites that have to be met by Ingress
controllers for enabling inbound traffic to Knative Services. Essentially, a (ingress-)gateway needs to be able to
manipulate a few critical HTTP headers and to provide protocol enhancements such as HTTPS termination and HTTP/2
transport with Prior Knowledge.

But most importantly, Knative ingress controllers need to satisfy Knative's own [`Ingress` API][ingress-api], which is
not to be confused with Kubernetes' `Ingress` resource. Each Knative Service has an associated [`Route`][route-api] that
defines how traffic should be distributed to the different revisions of this Service. That `Route` is used as the basis
for generating a unique `Ingress` configuration per Service, which in turn ingress controllers consume and translate to
their own primitives.

To enumerate a few features from the `Ingress` spec linked above, implementations are expected to provide name-based
routing, traffic splitting over multiple backends (Service revisions, e.g. for canary deployments), to support injecting
arbitrary headers into incoming requests (e.g. `Knative-Serving-Revision`, to let the autoscaler know what revision is
to be woken up), or even to provide different types of visibility (e.g. restrict traffic to clients located inside the
same cluster).

It can be worth mentioning that acquiring the configuration for the protocol selection in Knative Services is currently
a bit more subtle than reading an attribute from the `Ingress` configuration, since that information comes directly from
the Pod template declared inside the Service itself. This somewhat inconsistent API should improve in the near future
with the adoption of Kubernetes proposals such as [Adding AppProtocol to Services][kep-appprotocol] but, for the time
being, gateway implementations must support that little trick as well.

[contract-conn]: https://github.com/knative/serving/blob/master/docs/runtime-contract.md#inbound-network-connectivity
[ingress-api]: https://knative.dev/docs/reference/serving-api/#networking.internal.knative.dev/v1alpha1.Ingress
[route-api]: https://knative.dev/docs/reference/serving-api/#serving.knative.dev/v1beta1.Route
[kep-appprotocol]: https://github.com/kubernetes/enhancements/pull/1422

## A solid candidate: Gloo

Now back to the initial statement, and my quest for an alternative to Istio in my local development environment. After
spending a few hours familiarizing myself with the Knative Serving ecosystem, I stumbled upon a pretty legitimate
project called [Gloo][gloo-landing] that satisfies the conditions described above. Gloo is, to quote its authors, a
_"Kubernetes-native ingress controller, and next-generation API gateway"_. In a nutshell, Gloo provides advanced API
gateway features similar to Istio, without the service mesh overhead. Music to my ears.

The Gloo project is actually endorsed by Knative. It not only has its own installation instructions featured in the
Knative documentation, but is also part of its the end-to-end test suite to ensure things don't break along the way.

Another aspect that convinced me to give the project a try is its simple monolithic architecture and ease of deployment.
(oh, and also, [I promised][tweet]). Gloo has its own command-line utility, `glooctl` (pronounced "gloo-cuddle", _wink
wink_), which can install the solution in a single command within seconds. There are no complicated parameters to dig
from the documentation or long Helm charts to navigate, it's all self-contained. WIN.

```console
$ glooctl install knative --install-knative=false

Creating namespace gloo-system... Done.
Starting Gloo installation...

Gloo was successfully installed!
```

The command above deploys the Gloo control plane together with two proxies for Knative, one internal and one external,
to satisfy both public and private Knative Services. I set `--install-knative` to `false` because I want to deploy
Knative Serving myself from a development branch, instead of from the latest stable release.

The main `gloo` controller is the only component that defines resources requests. I would have appreciated to see some
default values set on the proxies as well but have to intention to stress my system for the time being anyway. Still, I
find the small number of deployed Pods very satisfying after a few months of using Istio in my local environment.

```console
$ kubectl describe node microk8s
...
Non-terminated Pods: (6 in total)
  Namespace     Name                     CPU Requests  CPU Limits  Memory Requests  Memory Limits
  ---------     ----                     ------------  ----------  ---------------  -------------
  gloo-system   discovery                0 (0%)        0 (0%)      0 (0%)           0 (0%)       
  gloo-system   gloo                     500m (8%)     0 (0%)      256Mi (2%)       0 (0%)       
  gloo-system   ingress                  0 (0%)        0 (0%)      0 (0%)           0 (0%)       
  gloo-system   knative-external-proxy   0 (0%)        0 (0%)      0 (0%)           0 (0%)       
  gloo-system   knative-internal-proxy   0 (0%)        0 (0%)      0 (0%)           0 (0%)       
  kube-system   coredns                  100m (1%)     0 (0%)      70Mi (0%)        170Mi (1%)   
```

Compared to Istio, the number of custom resources deployed by Gloo is insignificant due to the absence of service mesh
features.

```console
$ kubectl get crd
NAME
authconfigs.enterprise.gloo.solo.io
gateways.gateway.solo.io
proxies.gloo.solo.io
routetables.gateway.solo.io
settings.gloo.solo.io
upstreamgroups.gloo.solo.io
upstreams.gloo.solo.io
virtualservices.gateway.solo.io
```

There are other reasons to find Gloo attractive in my opinion. Unlike the Istio integration in Knative, which relies on
a separate controller to bridge the gaps between the gateway and the platform, the Gloo control plane embeds a
translator that transparently converts Knative `Ingress` configurations to Gloo `Proxy` objects. Gloo proxies are easy
to reason about in a Knative setup: there is one `Proxy` for external traffic (Services exposed to the outside world),
and one for private traffic (Services exposed only to cluster-local clients), very much like Istio `Gateways`. Each
proxy is supported by a distinct Kubernetes `Deployment` under the hood, and each proxy can serve ingress traffic for
a number of Knative Services ranging from zero to many.

```console
$ kubectl get proxies.gloo.solo.io -A
NAMESPACE     NAME
gloo-system   knative-external-proxy
gloo-system   knative-internal-proxy
```

<figure>
  <a href="{{ '/assets/img/knative-without-istio/gloo-diagram.svg' | prepend: site.baseurl }}">
    <img src="{{ '/assets/img/knative-without-istio/gloo-diagram.svg' | prepend: site.baseurl }}" alt="Gloo Ingress to Proxy translation">
  </a>
  <figcaption>Fig. - Gloo control plane generates Proxy API objects from Knative Services Ingress configurations</figcaption>
</figure>

As a demonstration, you will find below a YAML representation of an `Ingress` API object corresponding to a simple
"Hello World" Knative Service, and the corresponding external Gloo `Proxy` populated on the fly by Gloo. Notice the
different aspects of the `Ingress` API discussed previously: HTTP host names, headers, traffic splitting and visibility.

```yaml
# kubectl get ingresses.networking.internal.knative.dev helloworld-go -o yaml
---
apiVersion: networking.internal.knative.dev/v1alpha1
kind: Ingress
metadata:
  name: helloworld-go
  namespace: default
  labels:
    serving.knative.dev/route: helloworld-go
    serving.knative.dev/routeNamespace: default
    serving.knative.dev/service: helloworld-go
  ownerReferences:
  - apiVersion: serving.knative.dev/v1alpha1
    kind: Route
    name: helloworld-go
spec:
  rules:
  - hosts:
    - helloworld-go.default.svc.cluster.local
    - helloworld-go.default.example.com
    http:
      paths:
      - retries:
          attempts: 3
          perTryTimeout: 10m0s
        splits:
        - appendHeaders:
            Knative-Serving-Namespace: default
            Knative-Serving-Revision: helloworld-go-zf59x
          percent: 100
          serviceName: helloworld-go-zf59x
          serviceNamespace: default
          servicePort: 80
        timeout: 10m0s
    visibility: ExternalIP
  visibility: ExternalIP
status:
  loadBalancer:
    ingress:
    - domainInternal: knative-external-proxy.gloo-system.svc.cluster.local
  privateLoadBalancer:
    ingress:
    - domainInternal: knative-internal-proxy.gloo-system.svc.cluster.local
  publicLoadBalancer:
    ingress:
    - domainInternal: knative-external-proxy.gloo-system.svc.cluster.local
```

The same attributes can be found in the Gloo `Proxy`, just in a different shape:

```yaml
# kubectl -n gloo-system get proxies.gloo.solo.io knative-external-proxy -o yaml
---
apiVersion: gloo.solo.io/v1
kind: Proxy
metadata:
  name: knative-external-proxy
  namespace: gloo-system
  labels:
    created_by: gloo-knative-translator
spec:
  listeners:
  - name: http
    bindAddress: '::'
    bindPort: 80
    httpListener:
      virtualHosts:
      - name: default.helloworld-go-0
        domains:
        - helloworld-go.default.svc.cluster.local
        - helloworld-go.default.svc.cluster.local:80
        - helloworld-go.default.svc
        - helloworld-go.default.svc:80
        - helloworld-go.default
        - helloworld-go.default:80
        - helloworld-go.default.example.com
        - helloworld-go.default.example.com:80
        routes:
        - matchers:
          - regex: .*
          options:
            retries:
              numRetries: 3
              perTryTimeout: 600s
            timeout: 600s
          routeAction:
            multi:
              destinations:
              - destination:
                  kube:
                    port: 80
                    ref:
                      name: helloworld-go-zf59x
                      namespace: default
                options:
                  headerManipulation:
                    requestHeadersToAdd:
                    - header:
                        key: Knative-Serving-Namespace
                        value: default
                    - header:
                        key: Knative-Serving-Revision
                        value: helloworld-go-zf59x
                weight: 100
```

Since I am not running Istio in my local cluster, I was able to exclude the following files, pertaining only to Istio,
when I deployed Knative Serving from [development manifests][kn-dev]:

* `200-clusterrole-istio.yaml`
* `202-gateway.yaml`
* `203-local-gateway.yaml`
* `config-istio.yaml`
* `networking-istio.yaml`

We can validate that our Knative Service can get activated (scale from zero) and receive traffic by sending a HTTP
request to the Gloo proxy.

```console
$ kubectl get services.serving.knative.dev
NAME            URL                                        READY
helloworld-go   http://helloworld-go.default.example.com   True
```

I did not explicitly request the visibility of this Service to be cluster-local, so ingress traffic is served by the
external proxy:

```console
$ kubectl -n gloo-system get svc knative-external-proxy
NAME                     TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)
knative-external-proxy   LoadBalancer   10.152.183.248   203.0.113.1   80:32646/TCP,443:31851/TCP
```

The request is handled by the proxy and forwarded to the activator, which dispatches it to the Hello World service as
soon as a Pod becomes ready. Everything works the same way as with Istio from a developer's perspective. Noice!

```console
$ curl http://10.152.183.248 -D- -H 'Host: helloworld-go.default.example.com'
HTTP/1.1 200 OK
content-length: 20
content-type: text/plain; charset=utf-8
date: Fri, 24 Jan 2020 18:13:28 GMT
x-envoy-upstream-service-time: 2
server: envoy

Hello Go Sample v1!
```

[gloo-landing]: https://docs.solo.io/gloo/
[tweet]: https://twitter.com/AntoineCotten/status/1219708566195535872
[kn-dev]: https://github.com/knative/serving/blob/master/DEVELOPMENT.md

## Wrap up

As a developer who run multiple platforms on top of Kubernetes, I value lean solutions which deliver just the feature
set I need, and let me focus on what matters without diverting my attention to infrastructure-related challenges. I find
the integration between Knative and Gloo to work particularly well in this context. A persona like mine will appreciate
the choices offered by Knative's _swappable battery_ approach to ingress management, where it is possible to opt-out of
the heavy but battle-tested service mesh whenever it makes sense, without sacrificing any essential core functionality.

I am not the first person to consider such alternative. Matt Moore, one of the fathers of Knative and lead of the
Serving layer, recently came up with a custom distribution called [mink][mink] which delegates the Ingress
implementation to [Contour][contour-landing], a Kubernetes ingress controller powered by Envoy, the same service proxy
that powers Gloo.

Simplicity is a key factor in driving the adoption of an open-source platform like Knative, and I wish a project like
Gloo would become the default ingress gateway for Knative in the future, leaving the complexity of Istio to users who
have a real need for such advanced network layer.

[mink]: https://github.com/mattmoor/mink
[contour-landing]: https://projectcontour.io/

*Did you experiment with an alternative ingress gateway for Knative yourself? Please share your impressions and comment
below.*

*Post picture by [Johannes Plenio][postpic]*

[postpic]: https://pixabay.com/images/id-3332559/
