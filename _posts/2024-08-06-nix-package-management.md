---
layout: post
title: Scaling into Nix for multi-platform package management
blurb: >
  How I started using Nix flakes across my Linux and macOS workstations to
  manage system-wide packages and ephemeral development environments.
license: true
tags: [nix, productivity]
og_image: /assets/img/content/2024-08-06-nix-package-management/og-pic.webp
---

I tried Nix about 3 years ago by naively booting NixOS in WSL, without prior
exposure to the Nix ecosystem. At the time, I was mostly curious to find out
what the hype around the project was all about, and didn't have a concrete use
case in mind while approaching it. Needless to say, the experience left me with
a bitter taste to say the least.

Despite what may appear as the best way of experiencing Nix to a beginner,
NixOS is a brutal challenge to overcome to whoever isn't already deeply
familiar with Nix's novel concepts. The naming is one source of ambiguity of
its own, as the Nix project is part of the larger [NixOS _foundation_][nos-fnd]
yet works independently from the NixOS _distribution_ as a technology. To make
the barrier to entry even higher, Nix itself can be assimilated as many
different things: a language, a build system, a package manager, a development
environment, a configuration management system, etc. This very nature has a
high potential for raising varying expectations in different people.

I decided to revisit Nix with a renewed motivation, now that my wounds have
healed, by approaching it from a more sensible angle.

My first (second-)impression about the Nix ecosystem is that it feels
discordant in some aspects due to its perpetual transition phase. There is
clearly an _old_, well established Nix world, and a _new_ Nix world full of
modern concepts being steered by tenacious outliers (read on for more). This
feeling about the project's status seems to be shared among the majority of new
joiners, judging by the testimonials I have read on different online forums
such as the [NixOS Discourse][nos-forums] and [Reddit][nos-reddit].

Fortunately, I also have many positive things to opine on! As a matter of fact,
I found the Nix language pleasantly easy to learn despite its few quirks. If
the Nix learning curve can feel steep at times, it is because of the project's
breadth and conflicted documentation more than the intricacies of its language. 
I also found a lot of resources and advices within the community to be of high
quality, providing that one knowns where to search.

## The use case

Let me describe my actual use case, which is twofold:

1. Keep my system-wide packages consistent between my Linux (Debian in WSL) and
   macOS workstations, both in terms of command-line API and versions. I'm
   referring primarily to `git`, `make`, `curl`, `rigrep` and the like.

1. Spawn tailored development environments for different language toolchains
   on-demand, potentially per-project when additional tooling is required: Go,
   Rust, Lua, Python, Bash, etc. I want to do so without having any such
   toolchain/toolset globally installed, and without resorting to using
   containers, which on both of my workstations requires a dedicated virtual
   machine or WSL distro.

Despite it being possible and well supported via community projects, I
personally have no interest in managing my _configurations_ via Nix, either for
the operating system (Debian, macOS) or for my home directory ("dotfiles"). I
know that this is a popular practice among NixOS users especially, but I find
it silly and am convinced that there exist more appropriate tools for this job.

Overall, I feel that I was able to achieve my expected result effortlessly,
using exclusively core Nix features. I had however to sift through a fair
amount of noise originating from popular community projects, only to find out
that I didn't need them at all: [Home Manager][home-man], [devenv][devenv],
[devshell][devshell], ...

## Foreword about Nix flakes

Based on my grasp of where the Nix project is currently headed, I decided to
focus my learning and usage of Nix on features which are still officially
flagged as _experimental_:

- Nix [flakes][flakes]
- the "new" consolidated [`nix`][nix3] CLI and its flake-aware subcommands

In practice, this means that I am deliberately staying away from classic Nix
commands such as `nix-build`, `nix-env` and `nix-shell` in favor of the
aforementioned `nix` command, despite them having been around for as long as
Nix has existed and being thoroughly documented.

A flake is technically a file tree with a `flake.nix` file at its root. This
`flake.nix` file can declare _outputs_ as Nix expressions which consumers are
free to evaluate for whichever scenario is relevant to them: building packages,
running programs, spawning development environments, using library functions,
etc. Although outputs can have arbitrary names and values, various tools and
Nix projects rely on the existence of specific attributes, with values adhering
to a certain [schema][flake-schema]. Here is a non-exhaustive list of examples:

- `apps` is tried by [`nix run`][nix3-run]
- `devShells` is tried by [`nix develop`][nix3-dev]
- `packages` and `legacyPackages` are tried by [`nix run`][nix3-run],
  [`nix shell`][nix3-shell] and [`nix develop`][nix3-dev]
- `nixosConfigurations` and `nixosModules` are tried by [NixOS][nos-wiki]
- `homeConfigurations` is tried by [Home Manager][home-man] (community project)
- `darwinConfigurations` and `darwinModules` are tried by
   [nix-darwin][nix-darwin] (community project)

The fact that the outputs of a flake are ordinary Nix expressions means that
all the publicly available knowledge about _using_ Nix remains valid while
using Nix flakes.

If flakes are still regarded as experimental after 5 years of existence, it is
because they are not uniformly accepted within the Nix community due to several
[controversies][flake-controversies]. Nevertheless, they are so widely adopted
across the ecosystem that they can be considered the norm nowadays. The duality
of this situation is a major source of confusion for many.

One company in particular, [Determinate Systems][d-sys], is openly pushing hard
for getting these features out of their experimental spiral, to the point that
their popular Nix installer enables them by default (yet another source of
controversy within the Nix community). Besides all the advocacy work, the
company created a number of resources and services aimed at popularizing Nix
flakes, such as [Zero to Nix][zero-nix] and the [FlakeHub][flakehub] platform.

Despite the uncertainty around flakes, it appears that they have contributed
tremendously to the standardization of the Nix tooling so far by providing a
common entry point into Nix code. I firmly believe that they are here to stay,
and that the community will eventually converge towards solutions to the
problems that remain unaddressed since the original RFC.

## First stab at a package flake

Now, as announced earlier in this post, let me present to you the initial
version of the flake I came up with for installing my system-wide packages
across my Linux and macOS workstations.

Note that all the Nix-specific terms I use in this section are defined in the
[Nix glossary][nix-glossary]. This page comes in handy while learning Nix, I
recommend bookmarking it to be able to refer to it quickly.

```nix
# flake.nix
{
  description = "System packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: {
    packages = {
      x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.buildEnv {
        name = "system-packages";
        paths = [
          nixpkgs.legacyPackages.x86_64-linux.git
          nixpkgs.legacyPackages.x86_64-linux.gnumake
          nixpkgs.legacyPackages.x86_64-linux.curl
          nixpkgs.legacyPackages.x86_64-linux.jq
          nixpkgs.legacyPackages.x86_64-linux.fzf
          nixpkgs.legacyPackages.x86_64-linux.ripgrep
        ];
      };
      aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.buildEnv {
        name = "system-packages";
        paths = [
          nixpkgs.legacyPackages.aarch64-darwin.git
          nixpkgs.legacyPackages.aarch64-darwin.gnumake
          nixpkgs.legacyPackages.aarch64-darwin.curl
          nixpkgs.legacyPackages.aarch64-darwin.jq
          nixpkgs.legacyPackages.aarch64-darwin.fzf
          nixpkgs.legacyPackages.aarch64-darwin.ripgrep
        ];
      };
    };
  };
}
```

The flake has a single `inputs` entry, Nixpkgs, which is itself a flake and
which is fetched from its GitHub repository at the branch `nixpkgs-unstable`.
Nixpkgs provides Nix's standard and largest package collection, comprised of
[over 100,000 packages][repo-nixpkgs] at the time of writing. The _outputs of
that flake_ will be used inside my own flake's `outputs`.

Since I am only interested in dealing with packages, the `outputs` contain a
single attribute named `packages`. I mentioned this output in the previous
section, in which I described it as being used by commands such as `nix shell`.
This output has a single _package_, in Nix terms, named `default`, for each of
the systems that should be supported. That package is an aggregate of multiple
Nixpkgs packages, glued together as an _environment_ through a library function
named `buildEnv` (more about that later).

This version of the flake is fully functional but verbose. For instance, each
package appears twice: once per system `paths` list. Furthermore, the package
references inside these multiple `paths` lists are quite a mouthful, due to
package attributes being system-specific.

Before I attempt to make the flake's code more clever, let's open a Nix shell
based on the current `flake.nix` and observe a few things:

```console?prompt=$
$ nix shell
evaluating derivation 'git+file:///home/acotten/my-flake#packages.x86_64-linux.default'
copying '/home/acotten/my-flake/' to the store
evaluating file '/nix/store/46pzd5yf9k7ym8rv55rcsj42q6w84kbc-source/my-flake/flake.nix'
...
downloading 'https://api.github.com/repos/NixOS/nixpkgs/commits/7ce56e26c4f9ab04dfcaf20a733cd3343c58d953'
copying '«github:NixOS/nixpkgs/7ce56e26c4f9ab04dfcaf20a733cd3343c58d953»/' to the store
evaluating file '/nix/store/w06c717sf8h311m3mp5ivipiqnfjfj28-source/flake.nix'
...
instantiated 'openssl-3.0.14' -> '/nix/store/2mln7n1l0s3zciya6hqmh4wlb73s13h3-openssl-3.0.14.drv'
instantiated 'perl-5.38.2' -> '/nix/store/jdvgihv4irqffvyfj5cn212g1kxpyzxr-perl-5.38.2.drv'
instantiated 'python3-3.12.4' -> '/nix/store/4yc8g4z072mklvxf6hq787m2ihsd07pc-python3-3.12.4.drv'
instantiated 'gzip-1.13' -> '/nix/store/by61n1fs0fmpajknzi46npjy2hzfx01n-gzip-1.13.drv'
instantiated 'sqlite-3.46.0' -> '/nix/store/1jkfgd5583xnwqy7ashp3j34wb4bsrdf-sqlite-3.46.0.drv'
instantiated 'coreutils-9.5' -> '/nix/store/qa9l0jfnhjq2fb79gigzzzyimmc6gmlw-coreutils-9.5.drv'
instantiated 'ripgrep-14.1.0' -> '/nix/store/s1sprck1l3k9qh31dzhpbcpgq8l8pcmi-ripgrep-14.1.0.drv'
instantiated 'gnumake-4.4.1' -> '/nix/store/ydncg4g4mkwmjhx60mcfyzg6v8ddjmxr-gnumake-4.4.1.drv'
instantiated 'curl-8.8.0' -> '/nix/store/mnhscp4bp2hsqmyx9lqnxxiw2qx97x7q-curl-8.8.0.drv'
instantiated 'fzf-0.54.2' -> '/nix/store/gxqw9py7bjpnq3n51d9rf5d5235i9kks-fzf-0.54.2.drv'
instantiated 'jq-1.7.1' -> '/nix/store/7vvy0j80mmhp7s5scsy055kzi9ip9rnv-jq-1.7.1.drv'
instantiated 'git-2.45.2' -> '/nix/store/pa45s67361rfmkfrcfapcgv1a0l5gsbz-git-2.45.2.drv'
instantiated 'system-packages' -> '/nix/store/0j73k1cgjw26f0gn9r4x0pklg2x8s82a-system-packages.drv'
...
this derivation will be built:
  /nix/store/0j73k1cgjw26f0gn9r4x0pklg2x8s82a-system-packages.drv
these 106 paths will be fetched (59.01 MiB download, 361.80 MiB unpacked):
  /nix/store/zyrq8llafvxs3nlwpf9fmk4qqm9gw06s-openssl-3.0.14
  /nix/store/w6mq4l36lhikbw0ik46a78prpzhgkanx-perl-5.38.2
  /nix/store/1sgajx2r3bkriyxzwsahhva63p08pmac-python3-3.12.4
  /nix/store/ynhzyabgbx6fz49sy944ws9wnskangxc-gzip-1.13
  /nix/store/kpq03ylpiya2vbzja2313f1nnvg55sy9-sqlite-3.46.0
  /nix/store/7k0qi2r54imwjfs2bklg7fv0mn5jglil-coreutils-9.5
  /nix/store/ci25psqyv409fcigp56b4rx46dl6b68g-ripgrep-14.1.0
  /nix/store/6gylp4vygmsm12rafhzvklrfkbhwwq40-gnumake-4.4.1
  /nix/store/9v7hc5hm591539hlka47dj8ibjnbv0r2-curl-8.8.0
  /nix/store/dsvjjcysxvi2k5zc3rizxd74vw6ayw70-fzf-0.54.2
  /nix/store/p08mdq0qx0l3yzpnh17ll9dc47bwnvsv-jq-1.7.1
  /nix/store/x40bf8i3vwwjaxgm423f6b6rcy4qm5m3-git-2.45.2
...
copying path '/nix/store/zyrq8llafvxs3nlwpf9fmk4qqm9gw06s-openssl-3.0.14' from 'https://cache.nixos.org'
copying path '/nix/store/w6mq4l36lhikbw0ik46a78prpzhgkanx-perl-5.38.2' from 'https://cache.nixos.org'
copying path '/nix/store/1sgajx2r3bkriyxzwsahhva63p08pmac-python3-3.12.4' from 'https://cache.nixos.org'
copying path '/nix/store/ynhzyabgbx6fz49sy944ws9wnskangxc-gzip-1.13' from 'https://cache.nixos.org'
copying path '/nix/store/p08mdq0qx0l3yzpnh17ll9dc47bwnvsv-jq-1.7.1' from 'https://cache.nixos.org'
substitution of path '/nix/store/zyrq8llafvxs3nlwpf9fmk4qqm9gw06s-openssl-3.0.14' succeeded
substitution of path '/nix/store/w6mq4l36lhikbw0ik46a78prpzhgkanx-perl-5.38.2' succeeded
substitution of path '/nix/store/1sgajx2r3bkriyxzwsahhva63p08pmac-python3-3.12.4' succeeded
substitution of path '/nix/store/ynhzyabgbx6fz49sy944ws9wnskangxc-gzip-1.13' succeeded
substitution of path '/nix/store/p08mdq0qx0l3yzpnh17ll9dc47bwnvsv-jq-1.7.1' succeeded
...
building '/nix/store/0j73k1cgjw26f0gn9r4x0pklg2x8s82a-system-packages.drv'
building system-packages: created 210 symlinks in user environment
```

A few things happened here:

1. The process of turning the source tree of my flake into a [Nix
   derivation][nix-drv] started. Derivations are one of the most important core
   concepts of Nix. Essentially, a derivation is a description of a build task
   which produces output files at uniquely determined file system paths. My
   flake's derivation depends on other derivations, which are all its
   aggregated packages, as well as all the direct build and runtime
   dependencies of those packages. Executing the command `nix derivation show`
   inside the flake's directory would display all the derivations that are
   depended on by it.

1. The source tree of my flake was copied to the local [Nix store][nix-store],
   Nix's immutable data store located by default at `/nix/store`. The "source
   tree" here is simply composed of two files: the unmodified `flake.nix`,
   along with a new, auto-generated `flake.lock` that pins the `inputs`
   versions. A unique file path for the flake's source was created by
   generating a unique hash based on its contents. After being copied, the
   flake was evaluated.

1. The source trees denoted by the [flake references][flake-refs] declared as
   `inputs` of my flake were downloaded into the local Nix store, where its
   source tree was previously copied. As mentioned earlier, the only `input`
   here is Nixpkgs; it was declared as a reference to a GitHub repository, so
   its source tree was fetched via the GitHub REST API. That source tarball
   could have alternatively been fetched from an arbitrary HTTPS URL, like
   those served by FlakeHub for instance.

1. All the derivations my flake depends on were resolved and instantiated in
   the Nix store for evaluation.

1. Because Nix is configured by default to use `https://cache.nixos.org/` as a
   _substituter_ ([`man 5 nix.conf`][nix-conf-subs]), each of the above
   derivations' hash was tried against that substituter's URL. A substituter is
   an additonal Nix store, either remote or local, where pre-built store
   objects can be fetched from. A successful cache hit can prevent a costly
   local source build when the result of a derivation is already available in a
   trusted binary cache store. Since my packages originate from a recent
   revision of Nixpkgs, all derivations were successfully downloaded as
   pre-built store objects (libraries, executables, languages modules, ...),
   but that is not always the case. Packages from older Nixpkgs revisions, or
   packages originating from community projects, are unlikely to be found in
   the public NixOS cache, and need to be built locally by Nix.

1. Finally, the build of my flake's derivation completes after symlinking a
   number of files to their location inside the Nix store, where objects were
   previously either downloaded or built.

I am now inside a Nix shell containing the packages declared in my flake.

The first thing to notice inside that shell is that the paths of the requested
programs are known, and that they are located somewhere inside a Nix store path
suffixed with "system-packages", the name of the _environment_ (package
aggregate) defined inside `flake.nix`:

```console
(2) $ which git make jq
/nix/store/hnrynrmy95qk31km28nbajczrbcrz9pg-system-packages/bin/git
/nix/store/hnrynrmy95qk31km28nbajczrbcrz9pg-system-packages/bin/make
/nix/store/hnrynrmy95qk31km28nbajczrbcrz9pg-system-packages/bin/jq
```

Printing the value of the PATH environment variable indeed shows that this Nix
store path was prepended to my original PATH while dropping into the Nix shell:

```console
(2) $ printenv PATH
/nix/store/hnrynrmy95qk31km28nbajczrbcrz9pg-system-packages/bin:/usr/bin:/bin:/usr/sbin:/sbin
```

Inspecting the shared libraries of one of these programs with the `ldd` command
(`otool -L` on macOS) shows that it was dynamically linked against libraries
which are themselves located at Nix store paths, but not necessarily inside the
same path as my "system-packages" environment (package aggregate):

```console?prompt=$
(2) $ ldd "$(which git)"
linux-vdso.so.1
libpcre2-8.so.0 => /nix/store/iwdss5y8wq9nv4srk77q3gbfl4dhx8dc-pcre2-10.44/lib/libpcre2-8.so.0
libz.so.1 => /nix/store/phnpfqk1j35nil4hqgaslqm9a1q2gffy-zlib-1.3.1/lib/libz.so.1
librt.so.1 => /nix/store/0wydilnf1c9vznywsvxqnaing4wraaxp-glibc-2.39-52/lib/librt.so.1
libgcc_s.so.1 => /nix/store/kgmfgzb90h658xg0i7mxh9wgyx0nrqac-gcc-13.3.0-lib/lib/libgcc_s.so.1
libc.so.6 => /nix/store/0wydilnf1c9vznywsvxqnaing4wraaxp-glibc-2.39-52/lib/libc.so.6
/nix/store/0wydilnf1c9vznywsvxqnaing4wraaxp-glibc-2.39-52/lib/ld-linux-x86-64.so.2 => /lib64/ld-linux-x86-64.so.2
```

Linking to full Nix store paths at build time is made possible by an important
property of Nix derivations: reproducible builds. Because a Nix derivation has
deterministic references to all of its dependencies, and their build happens in
a sandbox, it is possible _for most builds_ to achieve bit-by-bit identical
results no matter where and when the build occurs.

This can be observed by inspecting the contents of a store derivation. In the
example below, I fetch information about the `pcre2` derivation from Nixpkgs at
the same revision as used inside the flake[^1], and can verify that its `out`
path matches the one the `git` executable was linked against:

```console
$ nix derivation show --system x86_64-linux 'nixpkgs#pcre2'
{
  "/nix/store/mcj0gzcx6rslvzr77rj0kv38bb0ckrbk-pcre2-10.44.drv": {
    ...
    "name": "pcre2-10.44",
    "outputs": {
      ...
      "out": {
        "path": "/nix/store/iwdss5y8wq9nv4srk77q3gbfl4dhx8dc-pcre2-10.44"
      }
    },
    "system": "x86_64-linux"
  }
}
```

For the bigger picture, let's display the file tree of my environment's Nix
store path:

```console?prompt=$
(2) $ tree /nix/store/hnrynrmy95qk31km28nbajczrbcrz9pg-system-packages
/nix/store/hnrynrmy95qk31km28nbajczrbcrz9pg-system-packages
├── bin
│   ├── curl -> /nix/store/g37vd707w8bdp919rdnwwld27wsmhqff-curl-8.8.0-bin/bin/curl
│   ├── fzf -> /nix/store/blqaxjh0wj83ayhqx1wwfjkrbhypml5s-fzf-0.54.2/bin/fzf
│   ├── fzf-share -> /nix/store/blqaxjh0wj83ayhqx1wwfjkrbhypml5s-fzf-0.54.2/bin/fzf-share
│   ├── fzf-tmux -> /nix/store/blqaxjh0wj83ayhqx1wwfjkrbhypml5s-fzf-0.54.2/bin/fzf-tmux
│   ├── git -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/bin/git
│   ├── git-credential-netrc -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/bin/git-credential-netrc
│   ├── git-cvsserver -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/bin/git-cvsserver
│   ├── git-http-backend -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/bin/git-http-backend
│   ├── git-jump -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/bin/git-jump
│   ├── git-receive-pack -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/bin/git-receive-pack
│   ├── git-shell -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/bin/git-shell
│   ├── git-upload-archive -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/bin/git-upload-archive
│   ├── git-upload-pack -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/bin/git-upload-pack
│   ├── jq -> /nix/store/yw7dn51dwbmw2pkx5fqhgadpzyv8f724-jq-1.7.1-bin/bin/jq
│   ├── make -> /nix/store/3ssglpx5xilkrmkhyl4bg0501wshmsgv-gnumake-4.4.1/bin/make
│   ├── rg -> /nix/store/whf1h65d54m8m6ws4sly5sqp0nz61zam-ripgrep-14.1.0/bin/rg
│   └── scalar -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/bin/scalar
├── include -> /nix/store/3ssglpx5xilkrmkhyl4bg0501wshmsgv-gnumake-4.4.1/include
├── lib -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/lib
├── libexec -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/libexec
└── share
    ├── bash-completion
    │   └── completions
    │       ├── git -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/share/bash-completion/completions/git
    │       ├── git-prompt.sh -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/share/bash-completion/completions/git-prompt.sh
    │       └── rg.bash -> /nix/store/whf1h65d54m8m6ws4sly5sqp0nz61zam-ripgrep-14.1.0/share/bash-completion/completions/rg.bash
    ├── fish
    │   ├── vendor_completions.d -> /nix/store/whf1h65d54m8m6ws4sly5sqp0nz61zam-ripgrep-14.1.0/share/fish/vendor_completions.d
    │   ├── vendor_conf.d -> /nix/store/blqaxjh0wj83ayhqx1wwfjkrbhypml5s-fzf-0.54.2/share/fish/vendor_conf.d
    │   └── vendor_functions.d -> /nix/store/blqaxjh0wj83ayhqx1wwfjkrbhypml5s-fzf-0.54.2/share/fish/vendor_functions.d
    ├── fzf -> /nix/store/blqaxjh0wj83ayhqx1wwfjkrbhypml5s-fzf-0.54.2/share/fzf
    ├── git -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/share/git
    ├── git-core -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/share/git-core
    ├── git-gui -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/share/git-gui
    ├── gitk -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/share/gitk
    ├── gitweb -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/share/gitweb
    ├── locale
    │   ├── be -> /nix/store/3ssglpx5xilkrmkhyl4bg0501wshmsgv-gnumake-4.4.1/share/locale/be
    │   ├── bg
    │   │   └── LC_MESSAGES
    │   │       ├── git.mo -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/share/locale/bg/LC_MESSAGES/git.mo
    │   │       └── make.mo -> /nix/store/3ssglpx5xilkrmkhyl4bg0501wshmsgv-gnumake-4.4.1/share/locale/bg/LC_MESSAGES/make.mo
    │   ├── ca -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/share/locale/ca
    │   └── ...
    ├── man
    │   ├── man1
    │   │   ├── curl.1.gz -> /nix/store/b4dcsaqi4rq412266xjgsdxhlz3j9j1l-curl-8.8.0-man/share/man/man1/curl.1.gz
    │   │   ├── fzf.1.gz -> /nix/store/rw7317jmzs7n6hb8vhifakg3d24pxk6b-fzf-0.54.2-man/share/man/man1/fzf.1.gz
    │   │   ├── fzf-tmux.1.gz -> /nix/store/rw7317jmzs7n6hb8vhifakg3d24pxk6b-fzf-0.54.2-man/share/man/man1/fzf-tmux.1.gz
    │   │   ├── git.1.gz -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/share/man/man1/git.1.gz
    │   │   └── ...
    │   ├── man5 -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/share/man/man5
    │   └── man7 -> /nix/store/zlkbk9a9l6jw9ghaknlyk6l73q263m44-git-2.45.2/share/man/man7
    ├── nvim -> /nix/store/blqaxjh0wj83ayhqx1wwfjkrbhypml5s-fzf-0.54.2/share/nvim
    ├── vim-plugins -> /nix/store/blqaxjh0wj83ayhqx1wwfjkrbhypml5s-fzf-0.54.2/share/vim-plugins
    └── zsh -> /nix/store/whf1h65d54m8m6ws4sly5sqp0nz61zam-ripgrep-14.1.0/share/zsh

75 directories, 220 files
```

One thing should jump out here: the directory structure follows the [Filesystem
Hierarchy Standard (FHS)][fhs] used in all UNIX operating systems. A few things
should appear familiar while looking closer at the file tree: the directory
hierarchy exposes programs and libraries, of course, but also man pages, shell
completions, and even a Vim plugin seemingly provided by the `fzf` package. In
other words, all the things provided by a typical APT or RPM package are
_realised_ from the equivalent Nix derivation. The difference with FHS is that
a Nix store path is not rooted at `/`. This should be reminiscent of a
[chroot(2)][chroot] or a [pivot_root(2)][pivroot] (used in Linux containers),
except that a Nix store path uses none of these to expose programs and
libraries to the environment.

Our tour of the "system-packages" environment comes to an end, let's now exit
back to the shell I was in before executing `nix shell`:

```console
$ exit
```

The programs declared inside the flake's `packages` attribute are no longer
available:

```console
$ which git make jq
git not found
make not found
jq not found
```

This is expected, because my PATH environment variable does not contain any Nix
store path inside that shell:

```console
$ printenv PATH
/usr/bin:/bin:/usr/sbin:/sbin
```

Note that exiting the Nix shell did not cause a sudden erasure of the data from
the Nix store. The store objects that were previously either downloaded or
built (libraries, executables, languages modules, ...) are still there, and
will remain inside the local Nix store until the next garbage collection.

While the environment inside the Nix shell looked satisfying to me, my goal of
having packages available _system-wide_ was not yet attained. I do not want to
start a new Nix shell every time I need to use these programs, since they are
programs I use a lot and want to be available at any time. Luckily, Nix has me
covered with a feature called [Nix profiles][nix-profile].

A profile has several interesting properties that fit the agenda:

- It aggregates the outputs of all installed packages into a single Nix store
  path, similarly to the way my "system-packages" environment was created by
  the `buildEnv` library function. This is not only true for packages installed
  declaratively through a flake like I did, but also packages installed
  imperatively through the `nix` CLI. This provides some great flexibility by
  allowing a mixture of installation patterns.

- The latest generation of the user's profile is symlinked at a fixed location,
  typically `~/.local/state/nix/profiles/profile`, which makes it easy and
  reliable to prepend to the user's PATH.

- They are set as [garbage collector roots][nix-gcroots], which ensures that
  programs aren't accidentally removed by garbage collections.

Let's add the "system-packages" environment (package aggregate) to my user's
profile:

```console
$ nix profile install
• Added input 'nixpkgs':
    'github:NixOS/nixpkgs/7ce56e26c4f9ab04dfcaf20a733cd3343c58d953?narHash=sha256-wXqWXhzH6kFGbPWMdn3eBPfv2nYxMyltKuj4jHY7OIA%3D' (2024-07-31)
```

A Nix store path was created for the environment (package aggregate).
Incidentally, it is the same path as the one created by running `nix shell`
earlier, since the dependencies haven't changed:

```console
$ nix profile list
Name:               my-flake
Flake attribute:    packages.x86_64-linux.default
Original flake URL: path:/home/acotten/my-flake
Locked flake URL:   path:/home/acotten/my-flake?lastModified=1722868680&narHash=sha256-6zu9OZxQHHHdK7I/AO4PtJn%2B5T7ovmXYcaSFTFQVk14%3D
Store paths:        /nix/store/hnrynrmy95qk31km28nbajczrbcrz9pg-system-packages
```

By following the symlink to the current generation of the profile, it can be
observed that it only contains symlinks to the Nix store path above:

```console?prompt=$
$ ls -l ~/.local/state/nix/profiles/profile/
lrwxr-xr-x@ 1 acotten  acotten  51 Aug  5 17:40 /home/acotten/.local/state/nix/profiles/profile/ -> /nix/store/xwjfjkm003nqdv438b0rn953mlpybpp7-profile
```

```console?prompt=$
$ tree /nix/store/xwjfjkm003nqdv438b0rn953mlpybpp7-profile
/nix/store/xwjfjkm003nqdv438b0rn953mlpybpp7-profile
├── bin -> /nix/store/f107pwv4rkrks85y7i51p684adc9n6sj-system-packages/bin
├── etc -> /nix/store/f107pwv4rkrks85y7i51p684adc9n6sj-system-packages/etc
├── include -> /nix/store/f107pwv4rkrks85y7i51p684adc9n6sj-system-packages/include
├── lib -> /nix/store/f107pwv4rkrks85y7i51p684adc9n6sj-system-packages/lib
├── libexec -> /nix/store/f107pwv4rkrks85y7i51p684adc9n6sj-system-packages/libexec
├── manifest.json
└── share -> /nix/store/f107pwv4rkrks85y7i51p684adc9n6sj-system-packages/share
```

If I were to add a package or another environment to my profile—for example
using an imperative command like `nix profile install 'nixpkgs#difftastic'`—the
top-level directories would change from symlinks to regular directories
containing symlinks to the outputs of the various packages installed in the
profile:

```console?prompt=$
$ tree /nix/store/fs2qcd9q9p261k4ijv9ahdmqhs44s35n-profile/bin
/nix/store/fs2qcd9q9p261k4ijv9ahdmqhs44s35n-profile/bin
├── ...
├── curl -> /nix/store/f107pwv4rkrks85y7i51p684adc9n6sj-system-packages/bin/curl
├── difft -> /nix/store/1n0v4lljxdwss4xd5h4013wwvdndfyz8-difftastic-0.60.0/bin/difft
└── ...

1 directory, 22 files
```

By prepending the path of my Nix profile to my PATH environment variable in my
shell's RC file, I am now able to use the packages from the flake inside all my
shells, exactly like I was in the Nix shell:

```sh
# ~/.zshrc
export PATH="/home/acotten/.local/state/nix/profiles/profile/bin:${PATH}"
```

```console
$ which git make jq
/nix/store/hnrynrmy95qk31km28nbajczrbcrz9pg-system-packages/bin/git
/nix/store/hnrynrmy95qk31km28nbajczrbcrz9pg-system-packages/bin/make
/nix/store/hnrynrmy95qk31km28nbajczrbcrz9pg-system-packages/bin/jq
```

This last step isn't necessary when Nix is installed using a Nix installer,
either the official one or the one from Determinate Systems. Both inject an
instruction into the global RC files of the running system that sources a
script called `nix-daemon.sh`, which takes care of this path mangling when
opening a new shell.

And this is it! With a fairly simple Nix flake I was able to declare
system-wide packages that I want installed across my Linux and macOS
workstations, with the guarantee that I will be using the exact same versions
of these packages everywhere. The same pattern can be applied to create
development environments that are spawned on demand as Nix shells, with
specific sets of tools enabled inside of them.

In the case where a specific software version is no longer available in the
public NixOS cache, Nix simply builds its package from source without requiring
me to install additional toolchains or build dependencies, and yields the same
output thanks to the reproducibility guarantee of Nix builds. None of these
aspects would have been possible by using APT and Homebrew, respectively.

I can check the `flake.nix` and `flake.lock` files into my dotfiles Git
repository alongside the rest of my home configurations, and conveniently fetch
possible changes whenever I switch laptops.

## Deconstruction of the flake

In the rest of this post, I am going the deconstruct the system flake presented
earlier. In this section, I will focus on inspecting the outputs of the
`nixpkgs` flake using the Nix REPL. Then, in the final section, I am going to
refactor the flake and demonstrate some clever usages of the Nix language.

First, let's open the Nix REPL:

```console
$ nix repl
```

I start by fetching the Nixpkgs flake from the same flake reference as used
inside `flake.nix` using the built-in function [`getFlake`][getFlake], and
assign it to a new variable named `nixpkgs` for further inspection:

```console
nix> nixpkgs = builtins.getFlake "github:NixOS/nixpkgs/nixpkgs-unstable"
```

As seen earlier, flakes have `inputs` and `outputs` attributes. Let's look at
the outputs of the Nixpkgs flake:

```console?prompt=>
nix> nixpkgs.outputs
{
  checks = { ... };
  htmlDocs = { ... };
  legacyPackages = { ... };
  lib = { ... };
  nixosModules = { ... };
}
```

Interestingly, the Nixpkgs exposes its own documentation via the `htmlDocs`
attribute. Although this practice doesn't seem to be standardized, it is a good
demonstration of the versatility of Nix flakes, and I encourage you to explore
these attributes on your own. One can imagine various practical uses for such
an attribute: a Nix language server, for instance, could take advantage of
the embedded documentation to display inline information about certain tokens
inside an IDE.

As for the name `legacyPackages`, know that it has nothing to do with actual
"legacy", and is in fact [a poorly named hack][legacyPackages] specific to the
Nixpkgs flake. Exposing packages behind the `legacyPackages` attribute instead
of the conventional `packages` attribute prevents the Nix tooling from choking
while displaying information about Nixpkgs, due to the **enormous** number of
packages it exposes, since `packages` is typically further evaluated by
commands like `nix flake show` to display additional information about the
packages exposed by a flake.

The `legacyPackages` attribute (`packages` in non-Nixpkgs flakes) is an
attribute set containing other attribute sets, each one corresponds to a type
of system supported by Nix:

```console?prompt=>
nix> nixpkgs.outputs.legacyPackages
{
  aarch64-darwin = { ... };
  aarch64-linux = { ... };
  armv6l-linux = { ... };
  armv7l-linux = { ... };
  i686-linux = { ... };
  powerpc64le-linux = { ... };
  riscv64-linux = { ... };
  x86_64-darwin = { ... };
  x86_64-linux = { ... };
}
```

Next, I'll peak at the packages available on `x86_64-linux` systems.

A word of warning: press the <kbd>TAB</kbd> key to display the _names_ of the
attributes for the chosen system like in the console sample below. **Do not
press <kbd>ENTER</kbd>** as this would evaluate each package's derivation
individually, which takes a very long time and unnecessarily writes a lot of
derivations to the local Nix store (exactly what naming the attribute
`legacyPackages` in place of `packages` was trying to avoid, remember?).

```console
nix> nixpkgs.outputs.legacyPackages.x86_64-linux.<TAB>
legacyPackages.x86_64-linux.a2jmidid   legacyPackages.x86_64-linux.lightworks
legacyPackages.x86_64-linux.a2ps       legacyPackages.x86_64-linux.ligo
legacyPackages.x86_64-linux.a4         legacyPackages.x86_64-linux.likwid
8<-------------------------- a lot more packages ----------------------------
legacyPackages.x86_64-linux.lightgbm   legacyPackages.x86_64-linux.zziplib
legacyPackages.x86_64-linux.lighttpd   legacyPackages.x86_64-linux.zzuf
legacyPackages.x86_64-linux.lightum
```

That is a whole lot of packages, over 100,000 as mentioned in the previous
section [First stab at a package flake](#first-stab-at-a-package-flake).

Conveniently, the `legacyPackages` attribute is available directly under
`nixpkgs`, additionally to being exposed as an attribute of the flake's
`outputs`. I am going to refer to it as `nixpkgs.legacyPackages` instead of
`nixpkgs.outputs.legacyPackages` from now on for brevity.

Let's check a derivation for the curiosity of it, such as the one of the `jq`
package:

```console
nix> nixpkgs.legacyPackages.x86_64-linux.jq
«derivation /nix/store/vsrf8afyxg4z72h4mfasmx6w92qfxds3-jq-1.7.1.drv»
```

A derivation is a plain ASCII text file which can be safely opened inside a
text editor. It is hard to understand as-is since it doesn't contain any line
terminator, however a similar, more digestible JSON output can be generated
using the command `nix derivation show 'nixpkgs#jq'` presented earlier.

Inside `flake.nix`, a function named `buildEnv` was encountered, which I simply
presented as a "library function". Although this function isn't
system-specific, it is exposed as a (repeated) attribute inside each system
attribute under `legacyPackages`, alongside package names, since it is meant to
be used with package arguments:

```console?prompt=>
nix> nixpkgs.legacyPackages.x86_64-linux.buildEnv
{
  __functionArgs = { ... };
  __functor = «lambda __functor @ /nix/store/c0kv8...-source/lib/trivial.nix:957:19»;
  override = { ... };
  overrideDerivation = «lambda overrideDerivation @ /nix/store/c0kv8...-source/lib/customisation.nix:151:32»;
}
```

The Nix REPL has a `:doc` command, unfortunately it wasn't meant for describing
the usage of functions exposed by flakes:

```console?prompt=>
nix> :?
The following commands are available:
  ...
  :doc <expr>    Show documentation of a builtin function
```

```console
nix> :doc nixpkgs.legacyPackages.x86_64-linux.buildEnv
error: value does not have documentation
```

There is also no formal documentation available for the `buildEnv` function
inside the [Functions reference][nixpkgs-man-funcs] section of the Nixpkgs
Reference Manual, only examples.

The `__functionArgs` attribute seems interesting though, let's check it out:

```console?prompt=>
nix> nixpkgs.legacyPackages.x86_64-linux.buildEnv.__functionArgs
{
  buildInputs = true;
  checkCollisionContents = true;
  extraOutputsToInstall = true;
  extraPrefix = true;
  ignoreCollisions = true;
  manifest = true;
  meta = true;
  name = false;
  nativeBuildInputs = true;
  passthru = true;
  paths = false;
  pathsToLink = true;
  postBuild = true;
}
```

That's a step forward, although the attributes aren't described. The meaning of
the boolean values is also unclear, although a call to the function without
argument would reveal that the ones with the value `false` have no default
value, and are therefore _mandatory arguments_.

To get information about the `buildEnv` function, I had to take a look at its
[source code][buildEnv]. To summarize, the Nixpkgs `buildEnv` function is used
to compose environments. An environment, in Nix terms, is a synthesized view of
some programs available in the Nix store, which is exactly what has been
observed in the Nix shell created in the previous section of this post.

You should now have a better understanding of a flake's structure and how to
identify its key attributes through exploration. At least this approach using
the Nix REPL helps _me_ tremendously while working with remote flakes.

## Refactoring of the flake

To be able to follow along and understand the flow of this final section, I
recommend a prior read-through of the [Nix language basics][nix-lang] page. It
is a relatively terse, non overly technical introduction to the Nix language,
and covers (literally) all the notions I use in the following refactoring.

If you still have the verbose initial version of my `flake.nix` in mind, you
may remember how each package reference had to be prefixed with the fully
qualified accessor to the corresponding `legacyPackages` system attribute:

```nix
x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.buildEnv {
  name = "system-packages";
  paths = [
    nixpkgs.legacyPackages.x86_64-linux.git
    nixpkgs.legacyPackages.x86_64-linux.gnumake
    # ...
  ];
};
```

Using a [`with ...; ...`][nix-lang-with] expression, the
`nixpkgs.legacyPackages.${system}` can be moved into scope, hence allowing
access to its attributes without repeatedly referencing the whole attribute
set:

```nix
x86_64-linux.default = with nixpkgs.legacyPackages.x86_64-linux; buildEnv {
  name = "system-packages";
  paths = [
    git
    gnumake
    # ...
  ];
};
```

This alone already feels like a considerable step forward. I could stop here,
and the flake would still be perfectly legible due to the small number of
systems and packages included:

```nix
# flake.nix
{
  description = "System packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: {
    packages = {
      x86_64-linux.default = with nixpkgs.legacyPackages.x86_64-linux; buildEnv {
        name = "system-packages";
        paths = [
          git
          gnumake
          curl
          jq
          fzf
          ripgrep
        ];
      };
      aarch64-darwin.default = with nixpkgs.legacyPackages.aarch64-darwin; buildEnv {
        name = "system-packages";
        paths = [
          git
          gnumake
          curl
          jq
          fzf
          ripgrep
        ];
      };
    };
  };
}
```

However, flakes can grow in complexity over time, with more systems to support,
more packages to include into environments, but also more top-level attributes,
as presented in the section titled [Foreword about Nix
flakes](#foreword-about-nix-flakes). Additionally, one may be required to
inject customisations that are system-specific into a flake, or to perform
dynamic modifications to Nixpkgs outputs via [Nixpkgs
overlays][nixpkgs-man-overlays], just to name a few common examples. For all
those reasons, making use of reusable code inside flakes can be as important as
keeping the codebase DRY in any software project.

A pattern to reduce the noise caused by per-system declarations of various
kinds is presented below:

```nix
allSystems = [ "x86_64-linux" "aarch64-darwin" ];

forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
  pkgs = nixpkgs.legacyPackages.${system};
});
```

This expression, although short, is intimidating at first. It took me a while
to understand it fully, and I will deconstruct it step by step later so that
you can understand it too. For the time being, it is sufficient to observe how
it can be used inside a [`let ... in ...`][nix-lang-let] expression to shorten
the body of the `packages` output:

```nix
{
  outputs = { self, nixpkgs }:
    let
      allSystems = [ "x86_64-linux" "aarch64-darwin" ];

      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
        pkgs = nixpkgs.legacyPackages.${system};
      });
    in
    {
      packages = forAllSystems ({ pkgs }: {
        default = with pkgs; buildEnv {
          name = "system-packages";
          paths = [
            git
            gnumake
            curl
            jq
            fzf
            ripgrep
          ];
        };
      });
    };
}
```

The `let ... in ...` construct allows assigning names inside `let` to literal
values or Nix expressions, and makes those named values available to the
expression that follows `in`. It is akin to declaring locally scoped variables
in an imperative language.

This "for all systems" pattern is very common within the Nix ecosystem. It is
being used exactly as presented above in most of the educational resources from
Determinate Systems and, more commonly, similar constructs are being used
through the popular [flake-utils][flake-utils] utility functions.

As promised, let's start deconstructing this expression step by step.

The first important bit is the [`genAttrs`][genAttrs] library function exposed
by the Nixpkgs flake:

```console
nix> nixpkgs.lib.genAttrs
«lambda genAttrs @ /nix/store/c0kv84h9nmr5k18wqrkr4cf4a1cj3z1q-source/lib/attrsets.nix:1246:5»
```

The part of the documented function signature that reads `genAttrs :: [ String
]` signifies that `genAttrs` accepts a list of strings. By calling it with a
list of system strings, an anonymous function ("lambda") is returned:

```console
nix> nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ]
«lambda genAttrs @ /nix/store/c0kv84h9nmr5k18wqrkr4cf4a1cj3z1q-source/lib/attrsets.nix:1247:5»
```

In the spirit of exploration, let's pass a dummy value to that anonymous
function, such as an empty attribute set:

```console?prompt=>
nix> nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ] {}
{
  aarch64-darwin = «error: attempt to call something which is not a function but a set: { }»;
  x86_64-linux = «error: attempt to call something which is not a function but a set: { }»;
}
```

Despite the fact that it contains errors, the printed output gives us a feeling
of what the `genAttrs` may be doing with the list argument that is passed to
it. Without having read the documentation, one could already infer from the
output that the function generates some kind of attribute set, in which each
attribute name corresponds to an element of the strings list received as
argument.

The printed output shows that the anonymous function attempted to call a
_function_ argument for each attribute of the generated attribute set, and that
this operation failed because the argument was not a function. By referring to
the documentation of the `genAttrs` function one more time, it can determined
that the expected function argument must have the signature `(String -> Any)`.

To start with a simple experiment, I pass an anonymous function ("lambda") with
a single argument `sys` (a string), and return that string argument `sys`
prepended with the string literal `arg:`:

```console?prompt=>
nix> nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ] (sys: "arg:" + sys)
{
  aarch64-darwin = "arg:aarch64-darwin";
  x86_64-linux = "arg:x86_64-linux";
}
```

Things are looking better this time around. When the result of calling
`genAttrs [ ... ]` was called with my lambda, each of the given list elements
(the system strings) was individually passed to the lambda as the `sys`
argument. The attribute set returned by this chain of function calls has values
matching the expression evaluated in the lambda's body. Neat!

Note that the expression in the lambda's body is not limited to evaluating to a
string, as denoted by the `-> Any` return type in the function signature. This
will be important later while deconstructing the `forAllSystems` function
further. I will illustrate this with another example, in which the lambda's
body evaluates to an _attribute set_ instead of a string:

```console?prompt=>
nix> :p nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ] (sys: { arg = sys; })
{
  aarch64-darwin = { arg = "aarch64-darwin"; };
  x86_64-linux = { arg = "x86_64-linux"; };
}
```

Now that the purpose of the `genAttrs` function is well understood, let's
assign its result to a variable named `genSysAttrs` and turn it into a named
function. This will facilitate its reuse:

```console
nix> genSysAttrs = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ]
```

Calling this named function without explicitly passing a list of system strings
is now possible, and the returned attribute set is the same as the one above:

```console?prompt=>
nix> :p genSysAttrs (sys: { arg = sys; })
{
  aarch64-darwin = { arg = "aarch64-darwin"; };
  x86_64-linux = { arg = "x86_64-linux"; };
}
```

Now let's progress by creating a lambda that looks slightly closer to the
definition of the `forAllSystems` function:

```console
nix> f: genSysAttrs (sys: f { sysstr = sys; })
«lambda @ «string»:1:1»
```

This function takes an arbitrary lambda `f` as argument, and calls that lambda
`f` with a named argument `sysstr`, which value is set to the value of `sys`.
As demonstrated in the previous call to `genSysAttrs`, `sys` will be one of the
supported system strings.

Again, let's assign this function to a variable named `forAllSystems1` and turn
it into a named function to facilitate its reuse:

```console
nix> forAllSystems1 = f: genSysAttrs (sys: f { sysstr = sys; })
```

To echo the previous experiment with the `genSysAttrs` function, I call
`forAllSystems1` with a lambda that prepends the received `sysstr` value with
the string literal `arg:`:

```console?prompt=>
nix> forAllSystems1 ({sysstr}: "arg:" + sysstr)
{
  aarch64-darwin = "arg:aarch64-darwin";
  x86_64-linux = "arg:x86_64-linux";
}
```

The result is identical to the first example call to `genSysAttrs`. This is
expected, but quite underwhelming. At this point, it isn't yet clear what
benefit is provided by this extra level of indirection.

To push this questioning further, let's call `forAllSystems1` with a lambda
that sets `sysstr` as the value of an attribute inside an attribute set:

```console?prompt=>
nix> :p forAllSystems1 ({sysstr}: { arg = sysstr; })
{
  aarch64-darwin = { arg = "aarch64-darwin"; };
  x86_64-linux = { arg = "x86_64-linux"; };
}
```

Here again, the result is identical to the second example call to the
`genSysAttrs` function.

To truly understand the power of the `forAllSystems` function chain, it is
necessary to amend the current version of `forAllSystems1`, and make it call
`f` with an argument value that is more interesting than just a `sys` string.

Let's first emulate the `legacyPackages` output of the `nixpkgs` flake with an
attribute set that has simplified package collections as values:

```console
nix> allPackages = {
       x86_64-linux = {
         foo = "foo-linux";
         bar = "bar-linux";
       };
       aarch64-darwin = {
         foo = "foo-macos";
         bar = "bar-macos";
       };
       i686-windows = {
         foo = "foo-windows";
         bar = "bar-windows";
       };
     }
```

Next, I amend the body of `forAllSystems1`'s nested lambda and call it
`forAllSystems2`. This time around, the lambda `f` is called with a `syspkgs`
argument which value _dynamically_ accesses an attribute from `allPackages`,
based on the value of `sys`:

```console
nix> forAllSystems2 = f: genSysAttrs (sys: f { syspkgs = allPackages.${sys}; })
```

I then call this new version of the function without performing any
transformation to `syspkgs`:

```console?prompt=>
nix> :p forAllSystems2 ({syspkgs}: syspkgs)
{
  aarch64-darwin = {
    bar = "bar-macos";
    foo = "foo-macos";
  };
  x86_64-linux = {
    bar = "bar-linux";
    foo = "foo-linux";
  };
}
```

So far so good, the function returned an attribute set of all packages per
_supported_ system (`i686-windows` didn't make the cut).

But, isn't it possible to generate the exact same attribute set using
`forAllSystems1`, the first revision of the `forAllSystems2` function? Good
observation, it is:

```console?prompt=>
nix> :p forAllSystems1 ({sysstr}: allPackages.${sysstr})
{
  aarch64-darwin = {
    bar = "bar-macos";
    foo = "foo-macos";
  };
  x86_64-linux = {
    bar = "bar-linux";
    foo = "foo-linux";
  };
}
```

It is even possible to generate that attribute set using the `genSysAttrs`
function alone:

```console?prompt=>
nix> :p genSysAttrs (sys: allPackages.${sys})
{
  aarch64-darwin = {
    bar = "bar-macos";
    foo = "foo-macos";
  };
  x86_64-linux = {
    bar = "bar-linux";
    foo = "foo-linux";
  };
}
```

So again, what benefit is provided by this extra level of indirection?

The answer is that it moves some of the complexity from the function signature
to the lambda's body. `forAllSystems2` encapsulates the access to `allPackages`
(my simplified mock of `nixpkgs.legacyPackages`), whereas `forAllSystems1` does
not:

```console?prompt=>
nix> forAllSystems1 ({sysstr}: allPackages.${sysstr})
nix> forAllSystems2 ({syspkgs}: syspkgs)
```

Although both revisions of the above function could be used to achieve the
desired result, `forAllSystems2` makes a lot more sense because the caller will
want to unconditionally access `allPackages.${sys}`.

Making the function signature simpler and clearer provides the most value when
accessing system-specific package attributes _across supported systems_. By
leveraging the fact that Nix is a _lazily_ evaluated language, a `foo` package
can be referenced as an attribute of `syspkgs` (which value is set to
`allPackages.${sys}` in the call to `f`) using the regular `.foo` notation:

```console?prompt=>
nix> :p forAllSystems2 ({syspkgs}: { mypkgs = [ syspkgs.foo ]; })
{
  aarch64-darwin = {
    mypkgs = [
      "foo-macos"
    ];
  };
  x86_64-linux = {
    mypkgs = [
      "foo-linux"
    ];
  };
}
```

In comparison, accessing individual system-specific packages using
`forAllSystems1` or `genSysAttrs` is more complex and error prone:

```console?prompt=>
nix> forAllSystems1 ({sysstr}: { mypkgs = [ allPackages.${sysstr}.foo ]; })
nix> genSysAttrs (sys: { mypkgs = [ allPackages.${sys}.foo ]; })
```

And voilà, just like that the `foo` package is requested in a single place and
elegantly expanded across all the systems the flake was designed to be
compatible with! While the data set used in this example was small, the pattern
demonstrated here becomes very powerful when applied onto a large package
collection such as Nixpkgs.

By way of final words, I present below the flake in its fully refactored form:

```nix
# flake.nix
{
  description = "System packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      allSystems = [ "x86_64-linux" "aarch64-darwin" ];

      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
        pkgs = nixpkgs.legacyPackages.${system};
      });
    in
    {
      packages = forAllSystems ({ pkgs }: {
        default = with pkgs; buildEnv {
          name = "system-packages";
          paths = [
            git
            gnumake
            curl
            jq
            fzf
            ripgrep
          ];
        };
      });
    };
}
```

This long write up presents an accurate picture of my journey learning and
using Nix so far. I hope it has been as educational to you as writing it has
been contemplative to me.

[^1]: The flake reference `nixpkgs` is a symbolic identifier for
      `github:NixOS/nixpkgs/nixpkgs-unstable` defined in the [Nix
      registry][nix3-registry] by default.

[nos-fnd]: https://nixos.org/
[nos-wiki]: https://nixos.wiki/
[nos-forums]: https://discourse.nixos.org/
[nos-reddit]: https://www.reddit.com/r/NixOS/

[nix-drv]: https://nix.dev/manual/nix/2.23/language/derivations.html
[nix-store]: https://nix.dev/manual/nix/2.23/store/
[nix-glossary]: https://nix.dev/manual/nix/2.23/glossary
[nix-profile]: https://nix.dev/manual/nix/2.23/package-management/profiles
[nix-gcroots]: https://nix.dev/manual/nix/2.23/package-management/garbage-collector-roots

[nix3]: https://nix.dev/manual/nix/2.23/command-ref/new-cli/nix
[nix3-run]: https://nix.dev/manual/nix/2.23/command-ref/new-cli/nix3-run#flake-output-attributes
[nix3-dev]: https://nix.dev/manual/nix/2.23/command-ref/new-cli/nix3-develop#flake-output-attributes
[nix3-shell]: https://nix.dev/manual/nix/2.23/command-ref/new-cli/nix3-env-shell
[nix3-registry]: https://nix.dev/manual/nix/2.23/command-ref/new-cli/nix3-registry
[nix-conf-subs]: https://nix.dev/manual/nix/2.23/command-ref/conf-file.html#conf-substituters

[flakes]: https://nix.dev/concepts/flakes
[flake-schema]: https://github.com/DeterminateSystems/flake-schemas#readme
[flake-controversies]: https://nix.dev/concepts/flakes#why-are-flakes-controversial
[flake-refs]: https://nix.dev/manual/nix/2.23/command-ref/new-cli/nix3-flake#flake-references

[home-man]: https://nix-community.github.io/home-manager/
[nix-darwin]: https://github.com/LnL7/nix-darwin#readme
[devenv]: https://devenv.sh/
[devshell]: https://numtide.github.io/devshell/

[d-sys]: https://determinate.systems/
[zero-nix]: https://zero-to-nix.com/
[flakehub]: https://flakehub.com/

[repo-nixpkgs]: https://repology.org/repository/nix_unstable

[fhs]: https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard
[chroot]: https://man7.org/linux/man-pages/man2/chroot.2.html
[pivroot]: https://man7.org/linux/man-pages/man2/pivot_root.2.html

[nixpkgs-man-funcs]: https://nixos.org/manual/nixpkgs/stable/#chap-functions
[nixpkgs-man-overlays]: https://nixos.org/manual/nixpkgs/stable/#chap-overlays

[getFlake]: https://nix.dev/manual/nix/2.23/language/builtins#builtins-getFlake
[legacyPackages]: https://github.com/NixOS/nixpkgs/blob/nixos-24.05/flake.nix#L80-L89
[buildEnv]: https://github.com/NixOS/nixpkgs/blob/nixos-24.05/pkgs/build-support/buildenv/default.nix
[genAttrs]: https://nixos.org/manual/nixpkgs/stable/#function-library-lib.attrsets.genAttrs

[nix-lang]: https://nix.dev/tutorials/nix-language
[nix-lang-with]: https://nix.dev/tutorials/nix-language#with
[nix-lang-let]: https://nix.dev/tutorials/nix-language#let-in

[flake-utils]: https://github.com/numtide/flake-utils#readme
