# DockStack – Docker on DevStack on Docker

[![Build Status](https://travis-ci.org/janmattfeld/DockStack.svg?branch=master)](https://travis-ci.org/janmattfeld/DockStack)

> This project installs DevStack inside a Docker container and integrates Zun, the current OpenStack container project.

## Why

A DevStack test installation should

1. Not alter the host system
2. Restart clean and fast
3. Allow snapshots
4. Be lightweight
5. Run guest applications fast

The most straight forward option `bare metal` lacks support for snapshots. It also alters the system heavily, rendering it unusable for other tasks. So it is only suitable for dedicated developer machines. Additionally, the well-known reset workflow of unstack/stack is unreliable, making this solution slow and annoying.

So, get a virtual machine and all of the above problems would be gone! But performance would be nice. Instead of `VirtualBox`, we could use `libvirt` for nested-KVM. If you already know libvirsh, that may work fine.

Running inside `LXD` containers might also be an option. They support multiple processes and feel more like a classic VM. Actually, they focus on IaaS [1]. However, an LXD-DevStack setup challenges just as much as on Docker [2].

[1]: https://www.ubuntu.com/containers/lxd
[2]: https://stgraber.org/2016/10/26/lxd-2-0-lxd-and-openstack-1112/

### Not invented here

Running Docker on DevStack actually has been done before [3]. However, we add the following:

1. A maintained base image of Ubuntu 16.04 LTS
2. Working systemd, as a base for
3. OpenStack Ocata and Pike
4. libvirt/QEMU support
5. Zun instead of the deprecated Nova Docker
6. A container-adjusted DevStack configuration

[3]: https://github.com/ewindisch/dockenstack

### Containers in OpenStack

- Zun, OpenStack API for launching and managing containers backed by different technologies including Docker
- Nova Docker (deprecated) [4], allows accessing containers via Nova's API, while Zun is not bounded by Nova's API
- Nova LXD, pushed by Canonical to promote LXD, OpenStack itself may be installed within LXD with Juju
- Magnum (Orchestration), a self-service solution to provision and manage a Kubernetes (or other COEs) cluster

[4]: https://wiki.openstack.org/wiki/Docker

## Start

Clone this repository and make sure your host offers at least

- Recent Linux (tested on Ubuntu 16.04 LTS and 17.04)
- 4 GB of RAM available for the container
- Docker (tested on 17.06.0-ce)

The `Makefile` includes a complete Docker lifecycle. Image build and DevStack installation are simply started with

```bash
make
```

The first run can take up to 50 minutes, downloading all Ubuntu and Python packages. Subsequent container starts are much faster because of the Docker cache.

Start a Cirros container via Zun

```bash
make test
```

More information on Zun can be found here [5].

Check your installation via Horizon at the displayed address or enter the running container directly with

```bash
make bash
```

[5]: https://docs.openstack.org/zun/latest/dev/quickstart.html

### Lifecycle

Altough a container restart is faster than a complete build, it still takes up to 20 minutes. So for experimenting use

- `docker commit` to save your running DevStack into the image
- Docker checkpoints [6] (experimental)
- the classic workflow of `/devstack/unstack.sh` and `/devstack/stack.sh`

[6]: https://criu.org/Docker
