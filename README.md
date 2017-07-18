# DockStack – Docker on DevStack on Docker

[![Build Status](https://travis-ci.org/janmattfeld/DockStack.svg?branch=master)](https://travis-ci.org/janmattfeld/DockStack)

> This project installs DevStack inside a Docker container and integrates Zun, the current OpenStack container project.

## Why

A DevStack setup should

1. Not alter the host system
2. Restart clean and fast
3. Allow snapshots
4. Be lightweight
5. Run guest applications fast

The most straight forward option `bare metal` lacks support for snapshots. It also alters the system heavily, rendering it unusable for other tasks. So it is only suitable for dedicated developer machines. Additionally, the well-known reset workflow of unstack/stack is unreliable, making this solution slow and annoying.

So, get a virtual machine and all of the above problems would be gone! Except for performance of course. Instead of `VirtualBox`, we could use `libvirt` with nested-KVM and speed things up. If you already know libvirsh, that may work fine.

Running inside `LXD` containers might also be an option. They support multiple processes and feel more like a classic VM. Actually, they focus on IaaS [[1]]. However, an LXD-DevStack setup challenges just as much as on Docker [[2]], [[9]].

[1]: https://www.ubuntu.com/containers/lxd
[2]: https://stgraber.org/2016/10/26/lxd-2-0-lxd-and-openstack-1112/
[9]: https://docs.openstack.org/devstack/latest/guides/lxc.html

### Not invented here

Running Docker on DevStack actually has been done before [[3]]. We add the following:

1. Ubuntu 16.04 LTS base image
2. systemd [[7]]
3. OpenStack Ocata and Pike
4. libvirt/QEMU instance support
5. Zun instead of the deprecated Nova Docker
6. container-adjusted DevStack configuration
7. Network configuration

[3]: https://github.com/ewindisch/dockenstack
[7]: https://docs.openstack.org/devstack/latest/systemd.html

### Containers in OpenStack

**Zun** [[5]], OpenStack API for launching and managing containers backed by different technologies including Docker

**Nova Docker** (deprecated) [[4]], allows accessing containers via Nova's API, while Zun is not bounded by Nova's API

**Nova LXD**, pushed by Canonical to promote LXD, OpenStack itself may be installed within LXD with Juju

**Magnum** (Orchestration), a self-service solution to provision and manage a Kubernetes (or other COEs) cluster

[4]: https://wiki.openstack.org/wiki/Docker

## Quickstart

The `Makefile` includes a complete Docker lifecycle. Image build and DevStack installation are simply started with

```console
$ git clone https://github.com/janmattfeld/DockStack.git
$ cd DockStack
$ make

This is your host IP address: 172.17.0.2
Horizon is now available at http://172.17.0.2/dashboard
Keystone is serving at http://172.17.0.2/identity/
The default users are: admin and demo
The password: secret

Services are running under systemd unit files.

DevStack Version: pike
OS Version: Ubuntu 16.04 xenial
```

The first run can take up to 50 minutes, downloading all Ubuntu and Python packages. Subsequent container starts are much faster because of the Docker cache.

### Usage

- Enter the main DevStack container directly with `make bash`.
- Start a Cirros container via Zun with `make test`.
- Check your installation via Horizon at the displayed address.

[5]: https://docs.openstack.org/zun/latest/dev/quickstart.html

### Network

Internet access for OpenStack instances

1. Edit the `public-subnet` and enable DHCP with a custom DNS server i. e. `8.8.8.8`.

Reaching an OpenStack instance from your host through Docker

1. Add custom rules to the default security group

```text
Ping: Ingress, IPv4, ICMP, Any, 0.0.0.0/0
```

2. On your host: Route to instances through docker instead of the (here unusable) Open vSwitch/Neutron interface br-ex

```console
$ ip route
172.24.4.0/24 dev br-ex proto kernel scope link src 172.24.4.1

$ sudo ip route del 172.24.4.0/24

$ sudo ip route add 172.24.4.0/24 via 172.17.0.2

$ ip route
172.24.4.0/24 via 172.17.0.2 dev docker0
```

### Configuration

Feel free to adjust the file `local.conf` for your needs [[8]].

[8]: https://docs.openstack.org/devstack/latest/configuration.html#local-conf

### Snapshots

Although a container restart is faster than a complete build, it still takes a few minutes. So for experimenting use

- `docker commit` to save your running DevStack into the image
- Docker checkpoints [[6]] (experimental)
- the classic workflow of `/devstack/unstack.sh` and `/devstack/stack.sh`

If you really messed it up, `make clean` followed by `make run` will set up a fresh DevStack.

[6]: https://criu.org/Docker

### Requirements

- Recent Linux (tested on Ubuntu 16.04 LTS and 17.04)
- 4 GB of RAM available for the container
- Docker (tested on 17.06.0-ce)
