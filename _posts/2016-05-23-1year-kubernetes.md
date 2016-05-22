---
layout: post
comments: true
title: 1 year, lessons learned from a 0 to Kubernetes transition
description: >-
  Look-back at the past year operating Kubernetes on AWS. The lessons I learned, the successes and failures I met with
  along the way.
image: 1year-kubernetes/post.jpg
tldr: >-
  You may want to write your own Ingress Controller for Application-level load-balancing. Set up a cluster wide
  redundant storage and avoid cloud-providers' block storage. Set resources requests and/or limits on every container.
  Use and abuse the Deployment API. Adopt label conventions across your apps. Use client certificate authentication
  moderately.
---

<span class="dropcap">I</span>t's been one year since I started performing my first experiments with Kubernetes,
Google's open-source orchestration platform for Linux Containers. One year since the concepts of this project alone
initiated a shift in my vision of platforms at scale. One year that made this DevOps buzzword finally become reality in
the team I was working in. Sounds like a good excuse to me for sharing the best-practices I have learned along the way
with that community of users and enthusiasts I see growing around the planet at a phenomenal speed.

Granted, one rarely starts from *zero* when it comes to running a productive environment on some bleeding edge software.
The process of change is generally initiated by a certain number of motivations and, although I may not have been in the
tech industry long enough to pretend my statement is an absolute truth, I strongly believe the top motivations result
from multiple platform-related pain points in the first place: complexity, scalability, insight, etc.

During the early days of a digital product every development team has, at some stage, to provide an answer to this very
question: "How to make our product available to the customer". Unless the budget allows investing in PaaS, the team
bootstraps the best platform they can with the knowledge and resources they have at that time, and uses it to serve the
first versions of their service, whether or not it is resilient to failure, whether or not metrics such as health and
performance are monitored, etc. Sometimes, especially in small development teams where everybody is wearing both Dev and
Ops hats, that very first iteration of the productive platform can stay around for a while and pain points just get
exacerbated over time.

At my previous company we were no different from any other startup and, not unexpectedly, we used to face challenges
that made us initiate the switch as well (see [my previous post][kismatic-fl] kindly published by Kismatic). The
migration to Kubernetes was a huge step for us, especially because we adopted Docker at the same time as we adopted the
orchestrator. In some way, Kubernetes made us adopt Docker. Hence the formula "0 to Kubernetes" in the title of this
post.

[kismatic-fl]: https://kismatic.com/use-case/getting-in-killer-shape-with-freeletics-on-kubernetes-and-docker/

## Abstract all the things

Good, we managed to abstract a lot of the underlying system complexity and hide it behind an API, this allowed us to
build a platform which primitives are accessible enough to a single Ops guy and a handful of developers, despite the
skyrocketing growth of our user base. So, after a year would I say that the adoption of Kubernetes was only for the
best? Pretty much.

> We've encapsulated a lot of the complexity required to move at scale into something you can download and install, all
> you know is that you'll deal with a small subset of APIs and knowledge, and you'll be able to utilize these systems.
> <footer>
>   &mdash; Kelsey Hightower, <cite><a href="http://thenewstack.io/tag/the-new-stack-at-scale/">The New Stack @ Scale</a> podcast, Show 6: "Managing Platforms at Scale"</cite>
> </footer>

Still, there is no such thing as a platform which does absolutely *everything* you want it to, in a way you want it to,
not even Kubernetes. I wish I had known a couple of things better before getting started. Some of these are due to my
lack of experience with the technology, others are strictly related to Amazon Web Services, our Cloud Provider, while
the rest simply did not exist a year ago and landed in newer releases. Let's take a closer look at those. 

### Ingress traffic

The Kubernetes network model makes it possible to expose an application as a single IP to the rest of the cluster. What
is doesn't allow, however, is to expose that service magically to the outside world, which is fine for things that are
typically not exposed to the public like data persistence layers, but a bit more problematic for the average web
application. If you're lucky enough to run in a supported Cloud Provider, you will be able to let Kubernetes provision
an external load-balancer for you and map your Service to it, at least that's the promise. In reality, from an AWS user
perspective, the implementation of this feature was particularly flawed even long after the official release of the
project in July last year. Progress has been made and numerous bugs have been fixed with the AWS integration since I ran
into issues myself, but other aspects of the network stack have to be taken into account.

Assuming that you're running inside an unsupported environment (or an environment with a broken external load-balancer
implementation), you might decide to leverage the NodePort Service type, which exposes a port in a certain range on
every node in your cluster. The concept is extremely convenient but can rarely be used alone in productive environments
for 2 reasons:

***The exposed NodePort is within an unprivileged port range***

Although this range is configurable I truly doubt that anybody wants to serve a public web application on port 30080
and, even if that was the case, your next application could not share the same port. A NodePort is unique within a
cluster.

***The core Kubernetes network stack works at the layer 3 of the OSI Model***

This does not facilitate interactions with the Application Layer (L7), like location-based proxying, cookie-based
session handling or even SSL termination assuming that your application speaks HTTP, which is only one among [many other
protocols][l7proto] working at the Layer 7 of the OSI Model.

Both of these are acceptable when each endpoint is used to serve a single application: a TCP load-balancer sits in front
of each backend and forwards requests to a destination port on a selection of machines, straightforward, battle-tested
and officially supported out-of-the-box as mentioned above. But microservices have been all the rage lately and an
*application* usually comprises multiple *services*, so network plumbing upstream is still necessary to some extent.

A new API called *Ingress* was introduced in Kubernetes 1.1 to make up for this lack, its goal is to represent HTTP
services by setting up HTTP proxies acting as endpoints in front of your application. The type of proxy software depends
on the Ingress Controller, Nginx and HAproxy are available as *contrib* projects but virtually anything can be
implemented. Problem: Ingress resources also run inside Kubernetes so it doesn't work if all your nodes reside inside a
private network (at least not without putting another element in front of it), and it is still limited when very
specific configurations are needed for each endpoint. That said, this kind of decoupling from the core API is going to
happen more often in the future (see [API Groups][apigroups]) so customizations should become more accessible to the
end-user with new releases.

<figure>
  <a href="{{ '/assets/img/1year-kubernetes/ingress.png' | prepend: site.baseurl }}">
    <img src="{{ '/assets/img/1year-kubernetes/ingress.png' | prepend: site.baseurl }}" alt="HTTP proxy deployed as a DaemonSet">
  </a>
  <figcaption>Fig1. - HTTP proxy deployed as a DaemonSet</figcaption>
</figure>

A while ago, before the Ingress Controllers were at the state they currently are, we managed to overcome these
limitations by deploying a proxy service as a DaemonSet. The role of this proxy is twofold: it terminates all TLS
connections coming from the outside and proxies HTTP traffic to different internal Services depending on the requested
URL. The configuration is static and baked inside a Docker image, good enough since it doesn’t change that often, and
this approach offers a very high level of control over the deployed configuration. In the end, all we had to do to make
our app publicly accessible was to map each pod to a certain Host Port (8443 on the figure) and forward the standard
HTTP ports 80/443 from a manually provisioned external load-balancer to all our nodes using plain TCP proxy. Nodes
register and deregister themselves with the load-balancer as they come up or down. The DaemonSet ensures that exactly
*one* proxy pod is running on each node node, which also prevents conflicting Host Ports as a side benefit. A minimal
effort for a good trade-off between control and comfort.

We've been running with that setup ever since, although the same result could be achieved using a custom Ingress
Controller nowadays.

[l7proto]: https://en.wikipedia.org/wiki/Application_layer#Other_protocol_examples
[apigroups]: https://github.com/kubernetes/kubernetes/blob/release-1.2/docs/proposals/api-group.md

### Storage

Being reachable is not the only kind of convenience needed by most modern applications, the data tier has a strict
dependency on storage by nature.  In-memory components are not excluded although they do not require real-time access to
the underlying storage, for the simple reason that data savepoints are critical to let any database recover from
disruptions. Therefore from my Ops guy's perspective reliability comes before performance, even when real-time access to
the storage is not critical.

Kubernetes is a project with a whole lot of moving parts by design, the simple fact that pods can start anywhere where
the scheduler sees fit in a potentially large cluster obliges administrators to think out their storage in a highly
dynamic and replicated way. Pinning an application to one particular node is neither a solution nor a recommended
pattern, Kubernetes has the same philosophy as any other redundant infrastructure, storage *should* survive a hardware
crash and all applications *should* be able to restart gracefully on a sane host in case of failure.

Cloud Providers provide services that solve this problem by letting customers create storage which is completely
independant from the machines providing the computing power. The guarantee is usually that this storage can be
associated to one or more *instances* depending on the provider and moved around on-demand, but here again there is a
subtlety. "*One or more*". For clustered environments this can actually make a big difference. Let me illustrate that
with an example.

You deploy a CMS-backed blog which receives regular updates in terms of content, but also in terms of visual design and
features. Your CMS is not designed to run on multiple servers so the media that have been uploaded to it are neither
replicated not stored on a consolidated storage network, which you actually do not own because it's either too expensive
or not available in AWS, your public cloud environment. So, you opt for pushing your CMS to a Docker image and storing
media on a dedicated Elastic Block Store, this way the CMS can be updated separately from the media files. During the
first rolling deployment (I cover deployments later in this post) the new pod starts on the same host as the previous
one and everything goes smoothly - downtime: 0, effort: minimal. The next day you want to deploy that brand new banner
that really kicks ass, so you trigger the same deployment procedure but this time, after 15 minutes, your new version is
still not online and your deployment status indicates *Failure*. So what happened?

<figure>
  <a href="{{ '/assets/img/1year-kubernetes/storage1.png' | prepend: site.baseurl }}">
    <img src="{{ '/assets/img/1year-kubernetes/storage1.png' | prepend: site.baseurl }}" alt="Pods sharing an EBS while running on the same instance">
  </a>
  <figcaption>Fig2. - Pods sharing an EBS while running on the same instance</figcaption>
</figure>

The first time both pods ended up running on the same host, effectively sharing the same physical data: a partition from
a device attached to the instance and mounted inside a volume. The old pod (v1) was sent to oblivion as soon as the new
one (v2) got in a *Running* state and the deployment was considered successful.

<figure>
  <a href="{{ '/assets/img/1year-kubernetes/storage2.png' | prepend: site.baseurl }}">
    <img src="{{ '/assets/img/1year-kubernetes/storage2.png' | prepend: site.baseurl }}" alt="Pods sharing an EBS while running on separate instances">
  </a>
  <figcaption>Fig3. - Pods sharing an EBS while running on separate instances</figcaption>
</figure>

The second time however, the new pod (v3) started on a different host than the one where the old one (v2) was running,
and remained in a *Creating* state for ever. The EBS store was never attached to the second node and the deployment
eventually failed.

The trick is that Amazon's EBS volumes can not be attached to multiple instances simultaneously, not even for read-only
operations contrary to GCE’s persistent disks for example, but Kubernetes won't take scheduling decisions accordingly
nor display precise feedback about such conflicts. Instead, it will keep trying over and over again with an increasing
backoff period, until the storage volume finally becomes available due to a human intervention. The induced downtime
includes the time necessary to gracefully terminate the old pod, detach the volume from the first node, attach it back
to another node, create the pod on that node: roughly 60 seconds if everything goes fine. Arguably the application from
my example had shortcomings in the first place which seasoned users already know how to overcome, nevertheless similar
deployment strategies should be planned with some extra care.

That's not all for AWS. Until Kubernetes 1.2 the implementation of the support for EBS volumes had an extremely
[nasty bug][issues15073] which prevented a volume from being attached to any instance if it had previously been attached
to another instance, due to Kubernetes improperly invalidating the device mapping cache. I remain convinced we're not
the only ones who faced interesting situations and unexpected downtimes because of that issue. This should have been
fixed by now, at least from my experience, but I've seen people [reporting otherwise][issues22433], so buyers beware.

What I want to point out is that so-called "elastic" storage from cloud providers is not always a suitable choice for
applications running in a context of high-availability (the much appreciated *zero downtime*), and with Kubernetes it is
somewhat easy to uncover the limits of such convenience storage services. If I were to perform another Kubernetes
installation with any kind of data persistence layer involved, I would cross out the dedicated IaaS block-level storage
option and make sure I have some robust, replicated storage in place before deploying the orchestration layer itself.
Luckily enough, Kubernetes supports Ceph and GlusterFS installations, [among others][volumetypes].

[issues15073]: https://github.com/kubernetes/kubernetes/issues/15073
[issues22433]: https://github.com/kubernetes/kubernetes/issues/22433
[volumetypes]: http://kubernetes.io/docs/user-guide/volumes/

### Resource allocation

With Kubernetes it is possible to achieve pretty high densities in terms of resource utilization, providing that you can
precisely predict how much resource each application requires to work in comfortable conditions under a maximum expected
load. To prove that theory, let me share the resource allocation of a typical productive system I've been running over
the past months.

The core product is served by a collection of Rails backends with different purposes spread across roughly 8 identical
machines and responding to 2000 requests per minute on average. A couple of satellite and administrative services are
running within the same cluster:

```
Capacity:
 cpu:		8
 memory:	15404072Ki
 pods:		110

Non-terminated Pods:		(11 in total)

Name			CPU Requests	CPU Limits	Memory Requests	Memory Limits
----			------------	----------	---------------	-------------
jenkins-slave-wcbae	400m (5%)	1 (12%)		700Mi (4%)	1000Mi (6%)
api-162-wd89r		710m (8%)	1210m (15%)	2700Mi (17%)	3100Mi (20%)
api-584-5av1x		700m (8%)	1200m (15%)	3500Mi (29%)	4000Mi (33%)
ingress-apis-o69r7	40m (0%)	40m (0%)	40Mi (0%)	40Mi (0%)
kube-ui-v4-xg1db	100m (1%)	100m (1%)	50Mi (0%)	50Mi (0%)
nrsysmond-dy2cc		10m (0%)	10m (0%)	25Mi (0%)	25Mi (0%)
sysdig-zge62		200m (2%)	200m (2%)	600Mi (3%)	600Mi (3%)
api-377-8fclk		410m (5%)	410m (5%)	930Mi (6%)	930Mi (6%)
api-196-7804y		310m (3%)	510m (6%)	1040Mi (6%)	1440Mi (9%)
api-196-is0km		310m (3%)	510m (6%)	1040Mi (6%)	1440Mi (9%)
sidekiq-386-tt7ys	85m (1%)	135m (1%)	1480Mi (9%)	1480Mi (9%)

Allocated resources:

  CPU Requests	CPU Limits	Memory Requests	Memory Limits
  ------------	----------	---------------	-------------
  3275m (40%)	5325m (66%)	12105Mi (79%)	14105Mi (92%)
```

As you can see, 40% of the CPU time and 79% of the memory of this host are requested. At this point you're probably
telling yourself this is insane, and it must seem like it, but all these applications are well under control. The main
reason is that requesting resources doesn't mean these will be consumed entirely at all times. In order to understand
how Kubernetes resource isolation works it's important to understand how Docker resource constraints work, and
inherently to be familiar with Cgroups. Let's take a trivial example, a 1-container pod is started with the following
`resources` spec:

```yaml
spec:
  resources:
    requests:
      cpu: 70m
      memory: 160Mi
    limits:
      cpu: 110m
      memory: 200Mi
```

When Kubernetes creates the container as part of the pod, it will set the following Docker constraints:

| "Memory"            | 209715200 |
| "MemoryReservation" | 0         |
| "CpuShares"         | 71        |
| "CpuQuota"          | 11000     |
| "CpuPeriod"         | 100000    |

In Cgroup dialect it means that this particular container can use at most **11%** of the run-time of any CPU **every
100ms**, and **200 Mebibyte** of physical memory. In case 100% of the overall CPU time of the host is requested (under
abnormally heavy load for example), the container will receive a proportion of CPU time ("share") equal to **71** out of
1024, spread across all CPUs, which actual value depends on the *share* allocated to all other containers running on
that system. What about the memory request? It is used for scheduling decisions in order to determine the best candidate
(node) at pod creation, which is also the role of its CPU counterpart.

With resources limits set, all containers are effectively limited to the amount of CPU and memory allocated to them.
Therefore, on the host described above we are most certainly walking on the edge of the available resources, but quite
certain that these will never get completely exhausted. Beware that this statement is based on two assumptions: every
container of every pod has its limits set, and no host process can consume more than the last 8% of the available
memory. The level of density one can achieve also depends on the kind of applications running within the cluster and the
choice of hardware. In the example above all prominent pods consume a relatively steady amount of memory whatever the
load on the services, so the limit on the memory can be set to a value relatively close to the request. CPU-wise, the
host has way more run-time available than the sum of all CPU limits, making the margin comfortable enough to run CI
systems and code analysis on the same hardware. Sometimes it's more realistic to reserve a certain type of hardware to
specific applications though.

<figure>
  <a href="{{ '/assets/img/1year-kubernetes/cluster_resources.png' | prepend: site.baseurl }}">
    <img src="{{ '/assets/img/1year-kubernetes/cluster_resources.png' | prepend: site.baseurl }}" alt="Cluster-level resource usage and limits">
  </a>
  <figcaption>Fig4. - Cluster-level resource usage and limits</figcaption>
</figure>


Kubernetes doesn't have dynamic resource allocation, which means that requests and limits have to be determined and set
by the user. When these numbers are not known precisely for a service, a good approach is to start it with overestimated
resources requests and no limit, then let it run under normal production load for a certain time: hours, days, weeks
according to the nature of the service. This time should be long enough to let you collect enough metrics and be able to
determine correct values with a small margin of error.

<figure>
  <a href="{{ '/assets/img/1year-kubernetes/resource_pod.png' | prepend: site.baseurl }}">
    <img src="{{ '/assets/img/1year-kubernetes/resource_pod.png' | prepend: site.baseurl }}" alt="Resource usage and limits of a group of pods">
  </a>
  <figcaption>Fig5. - Resource usage and limits of a group of pods</figcaption>
</figure>

Occasionally it is necessary to readjust the resources requests and limits of a running application because its
requirements have changed. On the graph above (fig5) a trained eye will have noticed that the average CPU and memory usage of
this service increased out of sudden. This could have been because of a sudden gain of popularity of our product, but
the actual reason is a downscale. Sometimes, sadly, you have to lay off a couple of workers, and from having originally
15 running instances (pods) of this API we decided to reduce that number to 10. As a result, resources got spread across
a lower number of processes and the average resource usage per-process increased.

This graph is interesting for another reason: besides the actual resource usage, it shows the requests (blue) and limits
(orange) set on each container. As you can see, the downscale made the memory usage per pod border the limit
dangerously, increasing the chance of heavy garbage collection or crash due to memory exhaustion.

<figure>
  <a href="{{ '/assets/img/1year-kubernetes/mem_resource_raise.png' | prepend: site.baseurl }}">
    <img src="{{ '/assets/img/1year-kubernetes/mem_resource_raise.png' | prepend: site.baseurl }}" alt="Raising memory resources requests and limits">
  </a>
  <figcaption>Fig6. - Raising memory resources requests and limits</figcaption>
</figure>

Memory requests and limits got raised in order to better stick to reality and the application was redeployed in order to
catch the changes, which you can see at 10:20 on this second graph above (fig6).

### Deployments

Being able to administer a platform via a set of APIs is a luxury that opens the door to many possibilities in terms of
process automation, including deployments. Providing that an application is packaged as a Docker or (hopefully someday)
OCI-compliant image, it can be handled as a single unit and deployed anywhere independently from the services it relies
on, that's the beauty of containers in a modern world. Well almost, in a modern *and* ideal world it should also adhere
to the [12-Factor principles][12factor] in order to be as portable as described, but I digress.

Although it was always possible to orchestrate deployments in a custom manner by interacting with the Kubernetes API,
the `kubectl` CLI contained some magic sauce which allowed users to perform rolling updates of an application even
before v1.0 was out. This mechanism makes sure that every pod running under the supervision of a replication controller
is replaced gracefully, one at a time. This workflow works as good in practice as on paper, but there is room for
improvement.

First of all everything happens client-side, lose connectivity to the API server and your deployment is interrupted
mid-way. Suboptimal. Then, there is no configuration flag to let the user configure things like parallelism or the time
a new pod should stay in a *Ready* state before replacing the next one. Finally, a rolling update can not be rolled back
to an older version, this requires redeploying that particular version like any other, and assumes that deployment
revisions are being tracked outside of Kubernetes.

A [new API called "Deployment"][deployapi] landed in Kubernetes 1.2, its purpose is to address the limitations described
above, and to be honest it addresses them all very well. This API is still in beta phase but mature enough to be used in
a productive environment from my own experience. *Deployment* objects also rely on the same rolling update mechanism,
just server-side and with finer-grained control. Consequently, parallel deployments are also handled without disturbing
ongoing rolling updates, which simplifies Continuous Deployment pipelines a lot since you can delegate the
responsibility of handling conflicts to the orchestrator.

It's not my goal to go into too much details here, let me just show you a quick example of the way I've been using it
myself:

```yaml
spec:
  replicas: 8
  revisionHistoryLimit: 5
  minReadySeconds: 20
  type: RollingUpdate
  strategy:
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 2
```

The strategy in the figure above makes sure at least **6** pods out of 8 (75%) are always running while a rolling
deployment is happening. It also prevents the expected number of replicas from being exceeded by more than **2** pods in
order to avoid a situation where pods could not be scheduled due to insufficient computing resources (remember the high
density I talked about in the previous section?). Finally, a pod is considered stable only after staying in the
*Running* phase for at least **20** seconds so that late crashes, typically due to timeouts, can automatically pause the
deployment.

```
NAME              DESIRED   CURRENT   AGE
api-1629265632    8         8         1d
api-2882306407    0         0         2d
api-293110170     0         0         4d
api-4229726616    0         0         7d
api-650543516     0         0         9d
```

You can also see in the figure above that a history of the **5** last deployments is kept in the Kubernetes datastore,
with a number of replicas set to 0. Each deployment gets a new revision number as soon as the pod template is altered,
that means every time a tag, resource definition, or even image tag changes, allowing you to rollback to one particular
version if necessary, without keeping old pods running in cluster for no reason.

<figure>
  <a href="{{ '/assets/img/1year-kubernetes/deployment_pipeline.png' | prepend: site.baseurl }}">
    <img src="{{ '/assets/img/1year-kubernetes/deployment_pipeline.png' | prepend: site.baseurl }}" alt="Kubernetes deployment pipeline on Jenkins">
  </a>
  <figcaption>Fig7. - Kubernetes deployment pipeline on Jenkins</figcaption>
</figure>

Overall we reduced our deployment time by 40% without decreasing the reliability of the whole process by simply moving
from plain ReplicationControllers to Deployments. I'll make a very bold statement here but if you're already running
Kubernetes 1.2 and still relying on the rolling-update mechanism provided by `kubectl` to deploy your applications,
you're doing it wrong. Convince me otherwise, I'd be happy to hear about other people's use cases.

[12factor]: http://12factor.net/
[deployapi]: http://blog.kubernetes.io/2016/04/using-deployment-objects-with.html

### Labeling

Kubernetes uses *Labels* internally to identify and select objects, a simple and powerful way to associate related
entities, but nothing more in appearance. There are yet interesting things one can do with Labels and Annotations
besides identifying resources, notably in terms of visualisation.

When an application is spread across multiple machines, like it usually is in Kubernetes, it's not sufficient to know
when things are getting slower or start spitting more errors overall, one should also be able to isolate the source of
the problem by looking at each pod individually, see how related nodes behave, compare to other unusual metrics at a
certain time. Likewise when the a node starts running out of resources it is critical to know which kind of process is
the culprit, which application it belongs to, which team is responsible for it. This is all done with the help of rich
metadata, and a structured hierarchy of Kubernetes Labels could be one way to salvation.

I realized the importance of having a consistent labeling convention when we evaluated [Sysdig][sysdig] as a monitoring
solution for our Kubernetes clusters. Before Sysdig we had been using the Heapster / InfluxDB / Grafana combo for
visualizing resource usage across our clusters, as you may have noticed earlier in this post. Heapster, at that point,
carried only little information with the metrics it exported: basically only the pod name, pod namespace, container name
and hostname. Consequently filtering options were somehow limited when relying purely on Heapster’s data.

Products like Sysdig take visualisation to another level by combining metrics collection with metadata exposed by both
Docker and Kubernetes. This allows you not only to calculate things like the CPU usage of a group of pods belonging to a
particular namespace, but also to see, for example, the average HTTP response time of all pods with the role ‘API’ in
version ‘canary' sorted by ‘Application'.

<figure>
  <a href="{{ '/assets/img/1year-kubernetes/sysdig_sort.png' | prepend: site.baseurl }}">
    <img src="{{ '/assets/img/1year-kubernetes/sysdig_sort.png' | prepend: site.baseurl }}" alt="Groups of containers sorted by a combination of namespace, labels and pod name in Sysdig">
  </a>
  <figcaption>Fig8. - Groups of containers sorted by a combination of namespace, labels and pod name in Sysdig</figcaption>
</figure>

The containers above (fig8) are grouped as follows: *Namespace name* > *Pod Label: 'application'* > *Pod name* >
*Container name* (as defined in the pod `template`)

<figure>
  <a href="{{ '/assets/img/1year-kubernetes/sysdig_label_sort.png' | prepend: site.baseurl }}">
    <img src="{{ '/assets/img/1year-kubernetes/sysdig_label_sort.png' | prepend: site.baseurl }}" alt="Custom label sort in Sysdig">
  </a>
  <figcaption>Fig9. - Custom label sort in Sysdig</figcaption>
</figure>

Another concrete example could be (fig9): *Namespace name* > *Pod Label: 'application'* > *Pod Label: 'component'*

<figure>
  <a href="{{ '/assets/img/1year-kubernetes/sysdig_dashboard1.png' | prepend: site.baseurl }}">
    <img src="{{ '/assets/img/1year-kubernetes/sysdig_dashboard1.png' | prepend: site.baseurl }}" alt="Monitoring dashboard based on metrics sorted by Labels">
  </a>
  <a href="{{ '/assets/img/1year-kubernetes/sysdig_dashboard2.png' | prepend: site.baseurl }}">
    <img src="{{ '/assets/img/1year-kubernetes/sysdig_dashboard2.png' | prepend: site.baseurl }}" alt="Monitoring dashboard based on metrics sorted by Labels">
  </a>
  <figcaption>Fig10. - Monitoring dashboards based on metrics sorted by Labels</figcaption>
</figure>

The dashboards in the figure above (fig10) show some metrics matching the scope defined in fig9 with `namespace ==
'bodyweight-api' && label.application == 'fl-backend-rails' && label.component == 'api'`.

Please note that Heapster metrics are now [way richer][heapster] than they used to be, so a similar demonstration would
also have been possible using Grafana nowadays. In the end, whatever monitoring solution you decide to implement to
monitor your Kubernetes cluster, you will largely benefit from having it actually aware of Kubernetes and not only of
Docker, as I quickly realized.

[sysdig]: https://sysdig.com/
[heapster]: https://github.com/kubernetes/heapster/blob/master/docs/storage-schema.md

### Authentication

If you ever had to do something like providing a remote employee access to an internal network over a VPN or
implementing PEAP authentication on a wireless network, you're most likely already familiar with Private Key
Infrastructures (PKI). This mode of authentication is supported by Kubernetes and it might be tempting to leverage it,
especially if the communications are to be secured over TLS within the cluster.

The biggest mistake I made when deploying Kubernetes in production was to rely exclusively on x509 certificates to
authenticate clients. I used them to authenticate Kubernetes components, but also all cluster users. In April 2015
Kubernetes still relied on the Nginx web server to terminate TLS connections, consequently one could benefit from
everything a web server could offer in terms of authentication.

A couple of weeks and a few versions later, Kubernetes supports PKI natively and the Nginx proxy is decommissioned from
our infrastructure. Only to realize after the departure of one employee that Kubernetes does not support Certificate
Revocation Lists. The entire CA had to be recreated, a new mean of authentication urgently adopted, and user secrets
widely re-distributed. On 2 clusters. A burden which could have been easily avoided by checking the specifications more
thoroughly.

Moral: make sure access to the cluster can be revoked individually *before* opting for one authentication method or
another. Lesson learned.

## Conclusion

Let's be honest, Kubernetes was initiated by Google engineers for running inside platforms designed by Google engineers.
You can undoubtedly expect a smooth experience on Google Cloud Engine, but make sure to test everything carefully if you
plan to run Kubernetes in another environment, where you're more likely to find edge cases or miss additional
integrations. Nevertheless, having a good understanding of the design patterns and API definitions together with
[keeping an eye on the project][kubeweekly] regularly was enough for me to overcome the rare imperfections I stumbled
upon during my journey. The project is extremely active and reporting issues with enough details and accurate
information always helps getting them resolved fast from my experience.

Kubernetes is not a sailboat anymore, it has become a whole fleet upon which many have already started building for
reasons which go far beyond the current trend around the container ecosystem. Get it right once for all and you will
wish you never have to come back to more traditional ways of managing platforms at scale. An ocean of new possibilities
lies right ahead.

*Feel free to comment on this post if you ever ran into similar situations yourself and/or would like to contribute
something to the elements that have been discussed.*

*Post picture by [skeeze][postpic]*

[kubeweekly]: https://kubeweekly.com/
[postpic]: https://pixabay.com/en/ship-helm-sunset-cutter-coast-guard-759954/
