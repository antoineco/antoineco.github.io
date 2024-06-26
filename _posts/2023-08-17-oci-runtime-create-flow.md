---
layout: post
title: 'OCI runtime: container creation flow'
blurb: Deep dive into the intricacies of Linux container runtimes.
license: true
tags: [containers, oci]
---

Lately, I have been digging into the [OCI Runtime specification][1] and
[`runc`][2], its reference implementation written in Go. Although I have been
working with containers for as long as Kubernetes has existed, I must now admit
that the runtime aspect of the standardization effort, which Linux containers
underwent throughout the existence of the Open Container Initiative (OCI), went
largely unnoticed to me.

Although I see it as a testament that the standardization was handled
skillfully, without causing massive disruptions to platforms that rely on the
container technology, it was about time for me to fill that knowledge gap.

In case you aren't familiar with the separation of concern between a _Container
manager_ and a _Container runtime_, I highly recommend reading [Journey From
Containerization To Orchestration And Beyond][3], by Ivan Velichko. It is a
clear and unambiguous entry point into this rabbit hole, with a bunch of
external links to additional high quality resources.

## Operations of an OCI Runtime

A container runtime must implement the following five self-explanatory
operations to be considered compliant with the OCI Runtime specification:

- Create
- Start
- State
- Kill
- Delete

These operations are abstract. The specification does not mandate any
particular command-line API to implement a CLI runtime like `runc`, although
some efforts exist to specify what _compliance_ means in terms of [command-line
interface][4]. This felt confusing to me at first.

Here is a sample visualization of a container lifecycle that leverages all five
of these operations:

<p style="max-width: 500px;">
  <img src="{{ "assets/img/content/2023-08-17-oci-runtime-create-flow/runc-seq.svg" | relative_url }}" alt="runc sequence">
</p>

In the rest of this article, I will focus solely on what exactly happens in the
**Create** and **Start** phases.

## Step by step

As seen in the previous illustration, running a containerized process through
an OCI runtime happens in two steps: create, start. For someone who typically
interacts with high level container runtimes such as Docker, it is tempting to
conflate these OCI operations with commands such as `docker container
[create|start]`. This can be deceptive because those aren't equivalent, despite
having similar semantics. To understand why, we have to inspect what happens to
OS processes when both of these operations are executed on the Linux host.

All experiments below are performed against an [OCI bundle][5] I called
`mybundle`. It was generated from the contents of the Docker Hub image
[`docker.io/library/nginx`][6], which rootfs can be exported using an OCI image
manipulation tool like [`crane`][7]. The directory structure of the bundle is
like below, where `config.json` is the [OCI runtime configuration file][8] for
the container, as generated by `runc spec` or a container runner/engine.

```
mybundle
├── config.json
└── rootfs
    ├── bin
    ├── dev
    ├── docker-entrypoint.sh
    ├── etc
    ├── home
    ├── lib
    ├── ...
    ├── usr
    └── var
```

`runc` requires a root directory, and a subdirectory matching the id of the
container (`mycontainer`) to store its state between each operation. These are
usually managed by a container manager like `containerd`, but we are operating
outside of the supervision of such manager here.

```sh
mkdir -p /run/runc/mycontainer
```

### Create

Let's invoke `runc create` on our bundle:

```sh
runc --root /run/runc \
  create \
  --bundle ~acotten/mybundle \
  --pid-file ~acotten/init.pid \
  mycontainer
```

Now let's query its state:

```console
$ runc --root /run/runc state mycontainer
{
  "ociVersion": "1.1.0",
  "id": "mycontainer",
  "pid": 19374,
  "status": "created",
  "bundle": "/home/acotten/mybundle",
  "rootfs": "/home/acotten/mybundle/rootfs",
  "created": "2023-08-17T19:10:49.347132023Z"
}
```

One intriguing detail is that the container state already includes a **process
id** (`19374`), although its status is `created` and not `running`. This is the
first major difference with `docker container create` or its clones, which
create a container from a specified image _without starting it_.

Now let's check the running processes. Inside a WSL instance based on Ubuntu,
the process tree looks like below:

```console
$ ps axjf
 PPID   PID  PGID   SID ... COMMAND
    0     1     0     0 ... /init
    1 18594 18594 18594 ...  \_ /init
18594 18595 18595 18595 ...      \_ -zsh
18594 19374 19374 19374 ...      \_ runc init
```

This output includes a second intriguing but significant detail: the pid
corresponds to a `runc init` process, which has nothing to do with our `nginx`
bundle.

### Start

Let's see what happens to this process when we invoke `runc start`:

```sh
runc --root /run/runc start mycontainer
```

For a very brief instant, we can witness the container's entrypoint command
being executed **with the same process id**, then immediately disappear:

```console
$ ps axjf
 PPID   PID  PGID   SID ... COMMAND
    0     1     0     0 ... /init
    1 18594 18594 18594 ...  \_ /init
18594 18595 18595 18595 ...      \_ -zsh
18594 19374 19374 19374 ...      \_ /bin/sh /docker-entrypoint.sh nginx -g daemon off
```

```console
$ ps axjf
 PPID   PID  PGID   SID ... COMMAND
    0     1     0     0 ... /init
    1 18594 18594 18594 ...  \_ /init
18594 18595 18595 18595 ...      \_ -zsh
                                 #gone!
```

Let's query its state one more time:

```console
$ runc --root /run/runc state mycontainer
{
  "ociVersion": "1.1.0",
  "id": "mycontainer",
  "pid": 0,
  "status": "stopped",
  "bundle": "/home/acotten/mybundle",
  "rootfs": "/home/acotten/mybundle/rootfs",
  "created": "2023-08-17T19:10:49.347132023Z"
}
```

The container now has the `stopped` status and its process id is no longer
being returned.

### Run

Before we dive a little further, let's try to explain the behaviour we just
observed. For this, we will be using one of `runc`'s higher level commands:
`runc run`. This command doesn't directly map to any of the OCI runtime
operations previously enumerated, but can be roughly described as a `create +
start`, with subtle differences.

First, we must delete the terminated container:

```sh
runc --root /run/runc delete mycontainer
```

Then invoke `runc run` the same way we invoked `runc create` earlier:

```sh
runc --root /run/runc \
  run \
  --bundle ~acotten/mybundle \
  --pid-file ~acotten/init.pid \
  mycontainer
```

This time around, the command doesn't return. Instead, the standard output of
the container's init process (`nginx`) is being printed to the standard output
of our terminal:

```
/docker-entrypoint.sh: Configuration complete; ready for start up
2023/08/17 19:12:34 [notice] 1#1: using the "epoll" event method
2023/08/17 19:12:34 [notice] 1#1: nginx/1.25.1
2023/08/17 19:12:34 [notice] 1#1: built by gcc 12.2.1 20220924 (Alpine 12.2.1)
2023/08/17 19:12:34 [notice] 1#1: OS: Linux 5.15.90.1-microsoft-standard-WSL2
2023/08/17 19:12:34 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1024:1024
2023/08/17 19:12:34 [notice] 1#1: start worker processes
```

In a separate terminal window, let's inspect the state of the container, as
well as the process tree:

```console
$ runc --root /run/runc state mycontainer
{
  "ociVersion": "1.1.0",
  "id": "mycontainer",
  "pid": 24977,
  "status": "running",
  "bundle": "/home/acotten/mybundle",
  "rootfs": "/home/acotten/mybundle/rootfs",
  "created": "2023-08-17T19:12:34.054132023Z"
}
```

The process id reported by `runc state` is now shown with the `running` status.

```console
$ ps axjf
 PPID   PID  PGID   SID ... COMMAND
    0     1     0     0 ... /init
    1 20434 20434 20434 ...  \_ /init
20434 20435 20435 20435 ...  \_ -zsh
20435 24963 24963 20435 ...      \_ runc --root /run/runc run --bundle /home/ac...
24965 24977 24977 24977 ...          \_ nginx: master process nginx -g daemon off
24977 24998 24977 24977 ...              \_ nginx: worker process
24977 24999 24977 24977 ...              \_ nginx: worker process
24977 25000 24977 24977 ...              \_ nginx: worker process
24977 25001 24977 24977 ...              \_ nginx: worker process
```

The corresponding process is visible in the process tree, and its command is
the `nginx` master process, per the container's configuration.

As you might have already guessed, the differences we observed during this
experiment are related to standard I/O streams (stdin, stdout, stderr):

- With `runc run`, the container's init process (`nginx`) remains parented to
  `runc`, which was forked from the shell, and therefore inherited the I/O
  streams of that shell ([foreground mode][9]).
- With `runc start`, the container's init process had already been orphaned and
  re-parented to the most immediate `init` host process, then reaped by it
  immediately after exiting due to a failed write to its closed stdout.

With a container manager such as `containerd` in the picture, the latter is
circumvented by interpolating a "container runtime shim" process between the
manager and the container process. Again, the role of the runtime shim is very
well described by Ivan in [Journey From Containerization To Orchestration And
Beyond][3] so I am not going to expand further on that topic.

But explaining the reason why the process exited in detached mode isn't what
I'm interested in here. Let's move on and see what actually happens in these
two disjointed phases of the creation of an OCI container (_Create_, _Start_).

## Multiple init phases

One might wonder what this container startup flow in two phases is good for, if
the container can technically be started in one; the OCI Runtime specification
doesn't expand on the intentions behind this design. I believe that this
question can be answered by drawing a parallel with some of the UNIX APIs for
process creation: `fork()` and `exec()`.

### Interlude: UNIX processes

In UNIX systems, running a program that is different from the calling program
requires two system calls:

- `fork()` to create an (almost) identical copy of the calling (parent) process
- `exec()` to transform the currently running program into a different running
  program, without creating a new process

This distinction allows the parent to run code between `fork()` and `exec()`.
This is essential for a program like a UNIX shell, as it enables features such
as redirection of I/O streams and other process manipulations.

For instance, when shell commands such as `echo 'hi' >out.txt` or `echo 'hi' |
wc` are executed, the shell performs the following actions under the hood:

1. Creates a child process with `fork()`
1. Closes the process' stdout, and obtain a file descriptor for whichever
   destination stdout should be redirected to (in the example above: a file or
   pipe)
1. Assigns this file descriptor to the process' stdout
1. Runs the `echo` command by calling `exec()`

This concept is very powerful, and concisely explained inside the fifth chapter
"Process API" of the (**free**) book [Operating Systems: Three Easy
Pieces][10], by Remzi and Andrea Arpaci-Dusseau.

### OCI runtime init

With these essential concepts clarified, we now have enough context to
understand what may happen between the _Create_ and _Start_ phases of an OCI
container's lifecycle.

In the first section of this article, we saw that `runc create` had eventually
given birth to a new process which wasn't the expected container's application,
but rather `runc` itself. A careful study of [libcontainer][11] reveals that
this phase, called _bootstrap_, starts a [parent process][12] with the command
[`/proc/self/exe init`][13] (the `runc` executable itself). This process
inherits the Linux cgroups and namespaces of the future container init process
(pid 1, `nginx`), receives the OCI runtime configuration of the container
process to be executed from its parent, and remains in that state until the
_Start_ phase is initiated[^1].

This is conceptually very similar to the `fork()` UNIX syscall, in the context
of a `fork() + exec()`.

<p style="max-width: 500px;">
  <img src="{{ "assets/img/content/2023-08-17-oci-runtime-create-flow/runc-create.svg" | relative_url }}" alt="runc create">
</p>

At the end of the _Create_ phase, `runc` writes the state file `state.json`
inside the root directory referenced by the `--root` CLI flag. This file
contains information such as the process id of the bootstrap process. It is read
by all subsequent `runc` commands, as a source of truth to be able to determine
the current status of the container based on the state of its init process.

```
/run/runc/mycontainer
└── state.json
```

Additionally—and I deliberately omitted to mention it until now—a named pipe
(FIFO) called `exec.fifo` was created inside that same root directory.

```
/run/runc/mycontainer
├── exec.fifo
└── state.json
```

This named pipe is what enables the host to communicate its intention to start
the container to the bootstrap process, and initiate the next phase: _Start_.
The write end of this named pipe is attached to the bootstrap process, while
its read end remains closed for now. The bootstrap process remains [stuck on a
blocking write][14] to `exec.fifo`, until `runc start` gives its "go" by
[reading from it][15].

At this stage, the caller—for instance a container manager like `containerd`—is
free to perform whatever additional step(s) it sees fit before starting the
container. In the wild, this often translates into setting up the container's
network interface(s) by invoking a chain of [CNI][16] plugins[^2]. After such
operations are complete, the caller may initiate the _Start_ phase.

What happens in this second and final phase of the container's startup is
literally [an `exec()` syscall][17] from the bootstrap process into the
container's init process, triggered by a read from the aforementioned
`exec.fifo` named pipe. The bootstrap process already received the container's
runtime configuration from the parent `runc` process during the _Create_ phase,
so there are no additional steps to be performed here.

![runc start]({{ "assets/img/content/2023-08-17-oci-runtime-create-flow/runc-start.svg" | relative_url }})

Finally, the `exec.fifo` named pipe is deleted.

## Appendix: bootstrap process uncut

The entirety of the `initProcess` struct—with a few irrelevant attributes
omitted for clarity—is exposed below for reference:

```go
libcontainer.parentProcess(*libcontainer.initProcess) *{
    cmd: *os/exec.Cmd {
        Path: "/proc/self/exe",
        Args: []string len: 2, cap: 2, [
            "/usr/local/bin/runc",
            "init",
        ],
        Env: []string len: 7, cap: 12, [
            "GOMAXPROCS=",
            "_LIBCONTAINER_INITPIPE=3",
            "_LIBCONTAINER_STATEDIR=/run/runc/mycontainer",
            "_LIBCONTAINER_LOGPIPE=4",
            "_LIBCONTAINER_LOGLEVEL=4",
            "_LIBCONTAINER_FIFOFD=5",
            "_LIBCONTAINER_INITTYPE=standard",
        ],
        Dir: "/home/acotten/mybundle/rootfs",
        Stdin: io.Reader(*os.File) *{
            file: *(*os.file)(0xc000082060),},
        Stdout: io.Writer(*os.File) *{
            file: *(*os.file)(0xc0000820c0),},
        Stderr: io.Writer(*os.File) *{
            file: *(*os.file)(0xc000082120),},
        ExtraFiles: []*os.File len: 3, cap: 4, [
            *(*os.File)(0xc000014bb8),
            *(*os.File)(0xc000014bc8),
            *(*os.File)(0xc000014be8),
        ],},
    messageSockPair: libcontainer.filePair {
        parent: *(*os.File)(0xc000014bb0),
        child: *(*os.File)(0xc000014bb8),},
    logFilePair: libcontainer.filePair {
        parent: *(*os.File)(0xc000014bc0),
        child: *(*os.File)(0xc000014bc8),},
    config: *libcontainer.initConfig {
        Args: []string len: 4, cap: 4, [
            "/docker-entrypoint.sh",
            "nginx",
            "-g",
            "daemon off;",
        ],
        Env: []string len: 4, cap: 4, [
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "NGINX_VERSION=1.25.1",
            "PKG_RELEASE=1",
            "NJS_VERSION=0.7.12",
        ],
        Cwd: "/",
        Capabilities: *(*"libcontainer/configs.Capabilities")(0xc0000bf200),
        User: "0:0",
        AdditionalGroups: []string len: 11, cap: 16, [
            "0","1","2","3","4","6","10","11","20","26","27"],
        Config: *(*"libcontainer/configs.Config")(0xc0000e21e0),
        Networks: []*libcontainer.network len: 0, cap: 0, nil,
        PassedFilesCount: 0,
        ContainerId: "mycontainer",
        Rlimits: []libcontainer/configs.Rlimit len: 1, cap: 1, [
            (*"libcontainer/configs.Rlimit")(0xc00002d4d0),
        ],},
    manager: libcontainer/cgroups.Manager(*libcontainer/cgroups/fs.manager) *{
        cgroups: *libcontainer/configs.Cgroup {
            Name: "",
            Parent: "",
            Path: "/default/1b260428b931d1c22fa618e251c7da66f84d18fe66f2ee67d...+15 more",
            ScopePrefix: "",
            Resources: *(*"libcontainer/configs.Resources")(0xc000002300),
            Rootless: false,
            OwnerUID: *int nil,},
        paths: map[string]string [
            "memory": "/sys/fs/cgroup/memory/default/1b260428b931d1c22fa618e2...+40 more",
            "net_cls": "/sys/fs/cgroup/net_cls/default/1b260428b931d1c22fa618...+42 more",
            "net_prio": "/sys/fs/cgroup/net_prio/default/1b260428b931d1c22fa6...+44 more",
            "": "/sys/fs/cgroup/unified/default/1b260428b931d1c22fa618e251c7d...+35 more",
            "cpuset": "/sys/fs/cgroup/cpuset/default/1b260428b931d1c22fa618e2...+40 more",
            "rdma": "/sys/fs/cgroup/rdma/default/1b260428b931d1c22fa618e251c7...+36 more",
            "devices": "/sys/fs/cgroup/devices/default/1b260428b931d1c22fa618...+42 more",
            "cpu": "/sys/fs/cgroup/cpu/default/1b260428b931d1c22fa618e251c7da...+34 more",
            "perf_event": "/sys/fs/cgroup/perf_event/default/1b260428b931d1c2...+48 more",
            "misc": "/sys/fs/cgroup/misc/default/1b260428b931d1c22fa618e251c7...+36 more",
            "cpuacct": "/sys/fs/cgroup/cpuacct/default/1b260428b931d1c22fa618...+42 more",
            "pids": "/sys/fs/cgroup/pids/default/1b260428b931d1c22fa618e251c7...+36 more",
            "blkio": "/sys/fs/cgroup/blkio/default/1b260428b931d1c22fa618e251...+38 more",
            "hugetlb": "/sys/fs/cgroup/hugetlb/default/1b260428b931d1c22fa618...+42 more",
            "freezer": "/sys/fs/cgroup/freezer/default/1b260428b931d1c22fa618...+42 more",
        ],}
    container: *libcontainer.linuxContainer {
        id: "mycontainer",
        root: "/run/runc/mycontainer",
        config: *(*"libcontainer/configs.Config")(0xc0000e21e0),
        cgroupManager: libcontainer/cgroups.Manager(*libcontainer/cgroups/fs.manager) ...,
        initPath: "/proc/self/exe",
        initArgs: []string len: 2, cap: 2, [
            "/usr/local/bin/runc",
            "init",
        ],
        initProcess: libcontainer.parentProcess(*libcontainer.initProcess) ...,
        initProcessStartTime: 0,
        state: libcontainer.containerState(*libcontainer.stoppedState) ...,
        created: (*time.Time)(0xc0001d42b0),
        fifo: *(*os.File)(0xc000014be8),},
    fds: []string len: 0, cap: 0, nil,
    process: *libcontainer.Process {
        Args: []string len: 4, cap: 4, [
            "/docker-entrypoint.sh",
            "nginx",
            "-g",
            "daemon off;",
        ],
        Env: []string len: 4, cap: 4, [
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bi...+1 more",
            "NGINX_VERSION=1.25.1",
            "PKG_RELEASE=1",
            "NJS_VERSION=0.7.12",
        ],
        User: "0:0",
        AdditionalGroups: []string len: 11, cap: 16, [
            "0","1","2","3","4","6","10","11","20","26","27"],
        Cwd: "/",
        Stdin: io.Reader(*os.File) ...,
        Stdout: io.Writer(*os.File) ...,
        Stderr: io.Writer(*os.File) ...,
        ExtraFiles: []*os.File len: 0, cap: 0, nil,
        Capabilities: *(*"libcontainer/configs.Capabilities")(0xc0000bf200),
        Rlimits: []libcontainer/configs.Rlimit len: 1, cap: 1, [
            (*"libcontainer/configs.Rlimit")(0xc00002d4d0),
        ],
        Init: true,
        ops: libcontainer.processOperations nil,
        LogLevel: "4",
        SubCgroupPaths: map[string]string nil,},
    bootstrapData: io.Reader(*bytes.Reader) *{
        s: []uint8 len: 32, cap: 32, [
            32,0,0,0,48,242,1,0,1,0,0,0,0,0,0,0,8,0,145,106,0,0,2,108,8,0,151,106,0,0,0,0],
        i: 0,
        prevRune: -1,},
}
```

Without going into the detail of each nested attribute, it is worth
highlighting a few of its properties:

- `cmd` describes the bootstrap command: `runc init`.
  - The named pipe `exec.fifo`, which is used for communicating the beginning
    of the _Start_ phase to the bootstrap process, has its file descriptor
    referenced in the environment variable `_LIBCONTAINER_FIFOFD`. It references
    the `cmd.ExtraFiles` item with the address `(*os.File)(0xc000014be8)`, which
    incidentally is also referenced by `container.fifo`.

- A de-serialized version of the OCI runtime configuration (`config.json`) is
  visible in the `config` field: container cmd, environment variables, working
  directory, etc.
  - A large part of this configuration is in fact hidden behind the
    `config.Config` and `config.Capabilities` fields, but expanding them here
    would add a lot of noise to the sample, and both are well described inside
    the OCI runtime specification.
  - This entire container configuration is communicated in JSON format to the
    bootstrap process over the UNIX socket pair `messageSockPair`, as soon as
    the bootstrap process is started. This data is critical as it allows the
    bootstrap process to `exec()` the container's command with the expected
    environment during the _Start_ phase.
- The `container` and `process` fields have some overlap with the `config`
  field. These are respectively the internal representation of the container (as
  seen by `runc`/`libcontainer`), and a representation of the container's init
  process specifically (`nginx`).
- The cgroups assigned to the bootstrap process, and therefore to the
  container's init process, are visible in the `manager` field: `cpu`, `memory`,
  `blkio`, etc.

[^1]: `runc create` actually forks twice during the bootstrap sequence to allow
    the second child to be started inside the final Linux namespaces, while
    the first child eventually exits. The detail of this flow would require a
    dedicated article.

[^2]: The CNI specification is not part of the Open Container Initiative (OCI).
    It is however a widely adopted standard within the Cloud Native Computing
    Foundation (CNCF) ecosystem, predominantly through the Kubernetes project.

[1]: https://opencontainers.org/posts/blog/2023-07-21-oci-runtime-spec-v1-1/
[2]: https://github.com/opencontainers/runc
[3]: https://iximiuz.com/en/posts/journey-from-containerization-to-orchestration-and-beyond/
[4]: https://github.com/opencontainers/runtime-tools/blob/v0.9.0/docs/command-line-interface.md
[5]: https://github.com/opencontainers/runtime-spec/blob/v1.1.0/bundle.md
[6]: https://hub.docker.com/_/nginx
[7]: https://github.com/google/go-containerregistry/tree/v0.16.1/cmd/crane#readme
[8]: https://github.com/opencontainers/runtime-spec/blob/v1.1.0/config.md
[9]: https://github.com/opencontainers/runc/blob/v1.1.9/docs/terminals.md#foreground
[10]: https://pages.cs.wisc.edu/~remzi/OSTEP/
[11]: https://pkg.go.dev/github.com/opencontainers/runc@v1.1.9/libcontainer
[12]: https://github.com/opencontainers/runc/blob/v1.1.9/libcontainer/container_linux.go#L338-L358
[13]: https://github.com/opencontainers/runc/blob/v1.1.9/libcontainer/factory_linux.go#L84-L85
[14]: https://github.com/opencontainers/runc/blob/v1.1.9/libcontainer/standard_init_linux.go#L233-L244
[15]: https://github.com/opencontainers/runc/blob/v1.1.9/libcontainer/container_linux.go#L327-L329
[16]: https://www.cni.dev/
[17]: https://github.com/opencontainers/runc/blob/v1.1.9/libcontainer/standard_init_linux.go#L261
