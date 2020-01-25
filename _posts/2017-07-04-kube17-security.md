---
layout: post
comments: true
title: Kubernetes v1.7 security in practice
description: Discover through practical examples what Kubernetes v1.7.0 brings in terms of security hardening.
image: kube17-security/post.jpg
---

<span class="dropcap">S</span>ecurity has been a long time concern within the Kubernetes community. Despite the
project's [outstanding growth][redmonk-analysis] in terms of adoption and contributions over the course of the past 2
years, many organizations still seem to approach the ecosystem with a lot of caution due to its rather green security
model.

I have witnessed a competitor rightfully bring this argument forward during a sales talk, and couldn't help thinking
about my own experience running Kubernetes. I had at that point only operated clusters where all users were, in a sense,
trusted: trained, responsible, working together on the same project. Neither the default all-or-nothing authorization
scheme nor the application secrets stored in plain text ever were a concern in that particular context. But what if
these clusters now fell into the hands of multiple teams, how to partition the access in a way that a human mistake or a
compromised application cause as little damage and disruption as possible?

The release of [Kubernetes v1.7.0][k8s17] last Friday demonstrates how seriously the project contributors take security
by introducing a bunch of features focused on cluster hardening, in the continuity of what v1.6.0 already brought with
the [Role Based Access Control][rbac] (RBAC) authorization mode. In this post, I'm going to show how these new concepts
can be applied to a running cluster with a few examples.

[redmonk-analysis]: http://redmonk.com/fryan/2016/11/08/kubernetes-from-evolution-to-an-established-ecosystem/
[k8s17]: https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG.md#v170
[rbac]: http://blog.kubernetes.io/2017/04/rbac-support-in-kubernetes.html

## RBAC (reminder)

The RBAC authorization mode is a feature that was graduated to beta in Kubernetes v1.6.0. It has a dedicated page in the
Kubernetes reference documentation: [Using RBAC Authorization][rbac-doc]. Feel free to skip to the next title if you
are already familiar with it.

With the RBAC authorization mode, any action on the Kubernetes REST API is denied by default. Permissions are granted
selectively via an explicit model where a set of "verbs" (HTTP method) is associated to a set of "resources" (Pods,
Services, Nodes, ...). These permissions are grouped inside roles which either apply to a single Namespace (Role) or the
entire cluster (ClusterRole). A Role can then be assigned to users, groups and/or applications (ServiceAccount) using a
Binding.

When the apisever is started with the flag `--authorization-mode=RBAC`, it automatically creates [a set of default roles
and bindings][rbac-defaults], listed below:

```console
$ kubectl get clusterroles

NAME
admin
cluster-admin
edit
system:auth-delegator
system:basic-user
system:controller:attachdetach-controller
system:controller:certificate-controller
system:controller:cronjob-controller
system:controller:daemon-set-controller
system:controller:deployment-controller
system:controller:disruption-controller
system:controller:endpoint-controller
system:controller:generic-garbage-collector
system:controller:horizontal-pod-autoscaler
system:controller:job-controller
system:controller:namespace-controller
system:controller:node-controller
system:controller:persistent-volume-binder
system:controller:pod-garbage-collector
system:controller:replicaset-controller
system:controller:replication-controller
system:controller:resourcequota-controller
system:controller:route-controller
system:controller:service-account-controller
system:controller:service-controller
system:controller:statefulset-controller
system:controller:ttl-controller
system:discovery
system:heapster
system:kube-aggregator
system:kube-controller-manager
system:kube-dns
system:kube-scheduler
system:node
system:node-bootstrapper
system:node-problem-detector
system:node-proxier
system:persistent-volume-provisioner
view
```

The role `system:kube-dns` is meant to be used by the Kubernetes DNS add-on. Let's examine and decrypt it:

```console
$ kubectl describe clusterrole system:kube-dns

Name:		system:kube-dns
Labels:		kubernetes.io/bootstrapping=rbac-defaults
Annotations:	rbac.authorization.kubernetes.io/autoupdate=true
PolicyRule:
  Resources	Non-Resource URLs	Resource Names	Verbs
  ---------	-----------------	--------------	-----
  endpoints	[]			[]		[list watch]
  services	[]			[]		[list watch]
```

This ClusterRole allows its subjects to *list* and *watch* resources of type Endpoint and Service, exclusively. It does
not grant permissions to modify these resources in any way (*update*, *delete*), nor to create new resources of this
type (*create*).

For almost each default ClusterRole, Kubernetes creates a corresponding ClusterRoleBinding:

```console
$ kubectl get clusterrolebinding

NAME
cluster-admin
system:basic-user
system:controller:attachdetach-controller
...
system:discovery
system:kube-controller-manager
system:kube-dns
system:kube-scheduler
system:node
system:node-proxier
```

Let's see what subject is allowed to use the `system:kube-dns` role:

```console
$ kubectl describe clusterrolebinding system:kube-dns

Name:		system:kube-dns
Labels:		kubernetes.io/bootstrapping=rbac-defaults
Annotations:	rbac.authorization.kubernetes.io/autoupdate=true
Role:
  Kind:	ClusterRole
  Name:	system:kube-dns
Subjects:
  Kind			Name		Namespace
  ----			----		---------
  ServiceAccount	kube-dns	kube-system
```

Looks like the ServiceAccount `kube-dns` in the Namespace `kube-system` will be granted the permissions described above.
Let's confirm that by creating it and sending a few HTTP requests to the API Server using the associated Bearer Token:

```console
$ kubectl -n kube-system create serviceaccount kube-dns
serviceaccount "kube-dns" created
```

```console
$ kubectl -n kube-system describe sa kube-dns
...
Tokens:		kube-dns-token-zhdfd
```

```sh
$ TOKEN="$(kubectl -n kube-system get secret kube-dns-token-zhdfd \
            -o jsonpath='{$.data.token}' | base64 -d)"
```

```console
$ curl -kD - -H "Authorization: Bearer $TOKEN" \
   https://apiserver:6443/api/v1/services

HTTP/1.1 200 OK
Content-Type: application/json
Date: Sun, 02 Jul 2017 18:17:15 GMT
Transfer-Encoding: chunked

{
  "kind": "ServiceList",
  "apiVersion": "v1",
  "metadata": {
    "selfLink": "/api/v1/services",
    "resourceVersion": "4799"
  },
  "items": [
    {
      ...
    }
  ]
}
```

The same operation fails when we attempt to list a Resource type this token doesn't have an explicit authorization for,
eg. Pods:

```console
$ curl -kD - -H "Authorization: Bearer $TOKEN" \
   https://apiserver:6443/api/v1/pods

HTTP/1.1 403 Forbidden
Content-Type: text/plain
X-Content-Type-Options: nosniff
Date: Sun, 02 Jul 2017 18:19:44 GMT
Content-Length: 88

User "system:serviceaccount:kube-system:kube-dns" cannot list pods at the cluster scope.
```

By providing explicit and [auditable][rbac-audit] security mechanisms, RBAC dramatically reduces the attack surface of a
cluster. Besides, the sensible bindings provided out-of-the-box make it quite effortless for the cluster operator to
apply the principle of least privilege to every Kubernetes client, down to the Kubernetes components themselves.

[rbac-doc]: https://kubernetes.io/docs/admin/authorization/rbac/
[rbac-defaults]: https://kubernetes.io/docs/admin/authorization/rbac/#default-roles-and-role-bindings
[rbac-audit]: https://developer.ibm.com/recipes/tutorials/service-accounts-and-auditing-in-kubernetes/

## Node Authorization

As explained in the previous section, RBAC allows subjects to perform certain actions on certain resource types. Yet,
the set of permissions required by critical cluster components like kubelet leaves a gap in this model as a single
compromised node could easily take down the entire cluster.

In order to get a sense of how loose the kubelet permissions are, let's take a look at the corresponding ClusterRole:

```console
$ kubectl describe clusterrole system:node

Name:		system:node
Labels:		kubernetes.io/bootstrapping=rbac-defaults
Annotations:	rbac.authorization.kubernetes.io/autoupdate=true
PolicyRule:
  Resources						Non-Resource URLs	Resource Names	Verbs
  ---------						-----------------	--------------	-----
  certificatesigningrequests.certificates.k8s.io	[]			[]		[create get list watch]
  configmaps						[]			[]		[get]
  endpoints						[]			[]		[get]
  events						[]			[]		[create patch update]
  localsubjectaccessreviews.authorization.k8s.io	[]			[]		[create]
  nodes							[]			[]		[create get list watch delete patch update]
  nodes/status						[]			[]		[patch update]
  persistentvolumeclaims				[]			[]		[get]
  persistentvolumes					[]			[]		[get]
  pods							[]			[]		[get list watch create delete]
  pods/status						[]			[]		[update]
  secrets						[]			[]		[get]
  services						[]			[]		[get list watch]
  subjectaccessreviews.authorization.k8s.io		[]			[]		[create]
  tokenreviews.authentication.k8s.io			[]			[]		[create]
```

Secrets, Certificates, Persistent Volumes, Nodes, ... so many critical resources every individual kubelet is allowed
to read, and sometimes write!

The [Node Authorizer][node-authz] authorization mode, together with the NodeRestriction admission controller, prevents
Kubernetes nodes from managing resources which are not associated to themselves. In other words, a kubelet can not:

* alter the state of resources which are not related to any Pod managed by itself
* access Secrets, ConfigMaps or Persistent Volumes / PVCs, unless they are bound to a Pod managed by itself
* alter the state of any Node but the one it is running on

Let's consider a cluster composed of 3 nodes "A", "B" and "C". A pod gets scheduled on node "C", the local kubelet
starts it and mounts a secret inside of it.

```console
$ kubectl create secret generic mysecret --from-literal=foo=bar
secret "mysecret" created
```

```console
$ kubectl run nginx --image=nginx:alpine --restart='Never' \
   --overrides='{"apiVersion": "v1", "spec": {"volumes": [{"name": "secretvol", "secret": {"secretName": "mysecret"}}]}}'
pod "nginx" created
```

```console
$ kubectl get pod -o wide
NAME      READY     STATUS    RESTARTS   AGE       IP            NODE
nginx     1/1       Running   0          10s       172.17.20.2   node-C
```

Now imagine node "A" is compromised, and tries to access the secret "mysecret" currently used by the pod "nginx". With
the standard RBAC authorization mode, any node belonging to the `system:nodes` group can access any secret:

```console?prompt=$
# confirm node-A's certificate Org field contains 'system:nodes'
$ openssl x509 -text -in kubelet.crt

Certificate:
    ...
        Subject: O=system:nodes, CN=kubelet
```

```console?prompt=$
# execute from node "A"
$ curl -kD - --cert kubelet.crt --key kubelet.crt \
   https://apiserver:6443/api/v1/namespaces/default/secrets/mysecret

HTTP/1.1 200 OK
Content-Type: application/json
Date: Sun, 02 Jul 2017 20:03:40 GMT
Content-Length: 366

{
  "kind": "Secret",
  "apiVersion": "v1",
  "metadata": {
    "name": "mysecret",
    ...
  },
  "data": {
    "foo": "YmFy"
  },
  "type": "Opaque"
}
```

The Node authorizer can be enabled in 3 steps:

1. Set the value of the `--authorization-mode` apiserver flag to `Node,RBAC` (*also works without RBAC*)
2. Append `NodeRestriction` to the value of the `--admission-control` apiserver flag
3. Generate a new X.509 certificate (or token) for each kubelet with the identity `system:node:<nodeName>`

Now, let's try to reproduce the same experiment as above, still from node "A":

```console?prompt=$
# confirm node-A's certificate CommonName field is 'system:node:node-A'
$ openssl x509 -text -in kubelet.crt

Certificate:
    ...
        Subject: CN=system:node:node-A
```

```console?prompt=$
# execute from node "A"
$ curl -kD - --cert kubelet.crt --key kubelet.crt \
   https://apiserver:6443/api/v1/namespaces/default/secrets/mysecret

HTTP/1.1 403 Forbidden
Content-Type: text/plain
X-Content-Type-Options: nosniff
Date: Sun, 02 Jul 2017 20:29:41 GMT
Content-Length: 110

User "system:node:node-A" cannot get secrets in the namespace "default".: "no path found to object"
```

However, node "C" can still read the secret because it is associated to a Pod running locally:

```console?prompt=$
# execute from node "C"
$ curl -kD - --cert kubelet.crt --key kubelet.crt \
   https://apiserver:6443/api/v1/namespaces/default/secrets/mysecret

HTTP/1.1 200 OK
Content-Type: application/json
Date: Sun, 02 Jul 2017 20:30:13 GMT
Content-Length: 366

{
  "kind": "Secret",
  "apiVersion": "v1",
  "metadata": {
    "name": "mysecret",
    ...
  },
  "data": {
    "foo": "YmFy"
  },
  "type": "Opaque"
}
```

The same holds true with resources modification. Let's try to delete the "nginx" Pod from node "A":

```console?prompt=$
# execute from node "A"
$ curl -X DELETE -kD - --cert kubelet.crt --key kubelet.crt \
   https://apiserver:6443/api/v1/namespaces/default/secrets/mysecret

HTTP/1.1 403 Forbidden
Content-Type: application/json
Date: Sun, 02 Jul 2017 20:45:55 GMT
Content-Length: 311

{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "pods \"Unknown\" is forbidden: node node-A can only delete pods with spec.nodeName set to itself",
  "reason": "Forbidden",
  "details": {
    "name": "Unknown",
    "kind": "pods"
  },
  "code": 403
}
```

Delete node "B" from node "A":


```console?prompt=$
# execute from node "A"
$ curl -X DELETE -kD - --cert kubelet.crt --key kubelet.crt \
   https://apiserver:6443/api/v1/nodes/node-B

HTTP/1.1 403 Forbidden
Content-Type: application/json
Date: Sun, 02 Jul 2017 20:49:52 GMT
Content-Length: 296

{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "nodes \"Unknown\" is forbidden: node node-A cannot modify node node-B",
  "reason": "Forbidden",
  "details": {
    "name": "Unknown",
    "kind": "nodes"
  },
  "code": 403
}
```

As you can see, the Node Authorizer feature adds another layer of security on top of RBAC, by allowing or rejecting
requests issued by Nodes based on a graph of related Pods, Secrets, Configmaps, PVCs, and PVs. This greatly reduces the
powers a node had over the complete infrastructure until this release, and I'm quite sure a lot of enterprise adopters
will be extremely excited about it.

[node-authz]: https://kubernetes.io/docs/admin/authorization/node/

## Secrets encryption

The etcd key-value store holds a critical role in a Kubernetes cluster as it is responsible for providing configuration
and state persistence to the control plane. etcd stores all its data in plain text, which means anybody with read access
to the data directory of a running etcd member or to a backup of the datastore can read the entire cluster state. For
critical resources, like application secrets or API tokens, this might obviously be very undesirable.

Thanks to a new experimental API server feature, it is now possible to instruct Kubernetes to encrypt arbitrary
resources at rest. Any resource type or resource group can be subject to encryption, although most people may want to
opt-in for encrypting Secrets and ConfigMaps only. Encryption is performed automatically during a write or an update of
the desired resources.

First of all let's create a new ConfigMap:

```console
$ kubectl create configmap encrypt --from-literal=foo=bar
configmap "encrypt" created
```

We can confirm the "encrypt" ConfigMap is currently stored in plain text:

```console
$ ETCDCTL_API=3 etcdctl get /registry/configmaps/default/encrypt | hexdump -C

00000000  2f 72 65 67 69 73 74 72  79 2f 63 6f 6e 66 69 67  |/registry/config|
00000010  6d 61 70 73 2f 64 65 66  61 75 6c 74 2f 65 6e 63  |maps/default/enc|
...
00000090  0a 03 66 6f 6f 12 03 62  61 72 1a 00 22 00 0a     |..foo..bar.."..|
```

The data encryption feature is enabled by passing an EncryptionConfig file to the
`--experimental-encryption-provider-config` apiserver flag, which format is described on the Kubernetes reference
documentation page [Encrypting data at rest][encrypt]. Let go ahead and enable the `aescbc` encryption provider for all
resources of type ConfigMap:

```yaml
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources: 
      - configmaps
    providers:
      - aescbc:
          keys:
            - name: mykey
              secret: HON5ISH9XMfFB6dnm25U0vSwxR58n7UrpxKPvmCJLTw=
```

After the apiserver gets restarted, the ConfigMap must be updated in order to get encrypted:

```console
$ kubectl get configmap encrypt -o json | kubectl replace -f -
configmap "encrypt" replaced
```

The "encrypt" ConfigMap is now effectively encrypted in etcd, notice its key was prefixed with `k8s:enc:aescbc:v1:`:

```console
$ ETCDCTL_API=3 etcdctl get /registry/configmaps/default/encrypt | hexdump -C

00000000  2f 72 65 67 69 73 74 72  79 2f 63 6f 6e 66 69 67  |/registry/config|
00000010  6d 61 70 73 2f 64 65 66  61 75 6c 74 2f 65 6e 63  |maps/default/enc|
00000020  72 79 70 74 0a 6b 38 73  3a 65 6e 63 3a 61 65 73  |rypt.k8s:enc:aes|
00000030  63 62 63 3a 76 31 3a 6d  79 6b 65 79 3a 1a bf 22  |cbc:v1:mykey:.."|
00000040  a5 88 6a 65 23 9f 05 ba  0e 7b 9c c8 a2 d2 c9 0a  |..je#....{......|
00000050  bc 57 d0 f0 2d bd 42 3b  8a e3 32 09 11 38 3f 0a  |.W..-.B;..2..8?.|
00000060  4a 1c 53 8b 07 ce eb da  14 21 c8 ba a0 98 4a f4  |J.S......!....J.|
00000070  7f 3f a7 54 23 eb f5 74  fe 9f 24 36 29 49 2b b4  |.?.T#..t..$6)I+.|
00000080  fe 91 88 52 a4 34 90 18  2e aa d8 07 b3 c1 aa 33  |...R.4.........3|
00000090  e0 54 a4 34 fe 32 a3 a9  50 fd 91 f1 62 a8 60 30  |.T.4.2..P...b.`0|
000000a0  cd e2 f9 80 6b c4 a2 9d  66 73 96 d1 94 62 a8 bc  |....k...fs...b..|
000000b0  78 8b 07 1b f2 c4 00 8c  b3 c8 5a e2 b7 7b 61 56  |x.........Z..{aV|
000000c0  b4 6c 96 80 35 8f 32 83  cc b7 aa c7 bb 0a        |.l..5.2.......|
000000ce
```

The ConfigMap is decrypted on the fly when requested via the Kubernetes API:

```console
$ kubectl describe configmap encrypt

...
Data
====
foo:
----
bar
```

Bear in mind that this beautiful feature is still experimental and likely to change from one release to another until
considered stable.

[encrypt]: https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/

## Audit Policies

The API server already provided, since v1.6.0, a way to turn on audit logs, which would result in logging every single
request and response to and from the Kubernetes REST API. This would provide a lot of insights to cluster
administrators, but also reveal potentially sensitive data and generate tons of undesired messages as a side effect.

From v1.7.0 on these logs are now configurable via more granular policies. Besides, they can be emitted via different
backends, including local audit files or webhooks.

Audit policies allow filtering certain types of requests similarly to a firewall. For example, one could want to trace
changes to ConfigMaps or Secrets without logging the associated request body in order to avoid exposing critical
information and void the benefits of data encryption described previously. Or one could decide to ignore all watches on
Services and Endpoints originating from the Kube DNS add-on.

Both these scenarios can be implemented using the following audit policy file:

```yaml
rules:
  # only log request metadata for any operation
  # on secrets or configmaps
  - level: Metadata
    resources:
      - group: ""
        resources:
          - secrets
          - configmaps

  # do not log watches on services and endpoints
  # originating from the "kube-dns" ServiceAccount
  - level: None
    users:
      - "system:serviceaccount:kube-system:kube-dns"
    verbs:
      - watch
    resources:
      - group: ""
        resources:
          - endpoints
          - services

  # catch-all
  # log everything else with metadata and req/resp bodies
  - level: RequestResponse
```

Two steps are necessary to enable this feature:

1. Pass `AdvancedAuditing=true` to the `--feature-gates` apiserver flag
2. Set the value of the `--audit-policy-file` apiserver flag to the path of the policy file created above

From there one can collect all audit logs inside the audit log file, which path is set using the `audit-log-path`
apiserver flag, but this backend can only log the requests and responses metadata, not their body. In order to inspect
the body of the audit events (as enabled in the catch-all rule by the `RequestResponse` level) we must send them to some
HTTP endpoint:

1. Create a free disposable webhook on [RequestBin][rqbin] (insecure, for testing only)
2. Create a kubeconfig file for the webhook audit backend:
```yaml
kind: Config
apiVersion: v1
clusters:
  - name: requestbin
    cluster:
      server: https://xyz12345.x.pipedream.net/
contexts:
  - name: webhook
    context:
      cluster: requestbin
current-context: webhook
```

3. Set the value of the `--audit-webhook-config-file` apiserver flag to the path of this file, and the value of
`--audit-webhook-mode` to `batch`

After restarting the apiserver, audit logs should start flowing to the Bin:

<figure>
  <a href="{{ '/assets/img/kube17-security/audit_requestbin.png' | prepend: site.baseurl }}">
    <img src="{{ '/assets/img/kube17-security/audit_requestbin.png' | prepend: site.baseurl }}" alt="Inspecting audit webhook HTTP requests">
  </a>
  <figcaption>Fig1. - Inspecting audit webhook HTTP requests</figcaption>
</figure>

Check out the documentation for more advanced examples: [Auditing][audit].

[audit]: https://kubernetes.io/docs/tasks/debug-application-cluster/audit/#audit-policy
[rqbin]: https://requestbin.com

## Final words

Whoever cares deeply about security will certainly welcome this Kubernetes release with praises. The features it
introduced significantly reduce the chances of an intrusion to turn into a mayhem, and brings the leading container
orchestration solution one step closer to enterprise-class data compliance. Kubernetes v1.7.0 also improves
traceability, a fundamental aspect of numerous IT audit processes.

NetworkPolicy is another major security-centric feature that was promoted to stable in the Kubernetes v1.7.0 release. I
decided not to tackle the subject in this post as its introduction dates back to v1.3.0, but would happily write
something about it on request.

*Want to share your own experience hardening Kubernetes, or simply discuss the topics from this post? Feel free to
comment below.*

*Post picture by [Gerhard Gellinger][postpic]*

[postpic]: https://pixabay.com/images/id-2100629/
