FROM ubuntu:16.04

EXPOSE \
    # OpenStack Dashboard (Horizon)
        80 \
    # Identity Service (Keystone API)
        5000 \
    # Compute (EC2 API)
        8773 \
    # Compute (Nova API)
        8774 \
    # Compute (Metadata API)
        8775 \
    # Block Storage (Cinder API)
        8776 \
    # Image Service (Glance API)
        9292

# Suppress unwanted debconf messages and questions during build
ARG DEBIAN_FRONTEND=noninteractive

#####################################################################
# Systemd workaround from solita/ubuntu-systemd and moby/moby#28614 #
#####################################################################
ENV container docker
# No need for graphical.target
RUN systemctl set-default multi-user.target
# Gracefully stop systemd
STOPSIGNAL SIGRTMIN+3
# Cleanup unneeded services
RUN find /etc/systemd/system \
         /lib/systemd/system \
         -path '*.wants/*' \
         -not -name '*journald*' \
         -not -name '*systemd-tmpfiles*' \
         -not -name '*systemd-user-sessions*' \
    -exec rm \{} \;
# Workaround for console output error moby/moby#27202, based on moby/moby#9212
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]

####################
# DevStack Preload #
####################
# Get Missing External System Dependencies for DevStack Setup
RUN apt-get update && apt-get --assume-yes --no-install-recommends install \
        # To Retrieve Fresh DevStack Sources
        ca-certificates \
        git \
        # Host IP Management (ip)
        iproute2 \
        # Dependency of PyECLib
        liberasurecode-dev \
        # Dependency of python-nss
        libnss3-dev \
        # Dependency of systemd-python
        libsystemd-dev \
        # Enabling KVM Guests
        libvirt-dev \
        # Distribution Identification
        lsb \
        # Network Detection (arp)
        net-tools \
        # Preload Fixes from /devstack/tools/fixup_stuff.sh
        python-virtualenv \
        software-properties-common \
    # Cleanup
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG DEVSTACK_BRANCH="master"
ARG PROJECTS_BRANCH="master"
# This OpenStack project repositories will be downloaded
ARG PROJECTS=" \
        keystone \
        nova \
        neutron \
        glance \
        horizon \
        zun \
        zun-ui \
        kuryr-libnetwork \
    "
# Clone DevStack, Requirements and OpenStack (Core) Projects
#  - To properly detect a container environment,
#    we need at least openstack-dev/devstack/commit/63666a2
RUN git clone git://git.openstack.org/openstack-dev/devstack --branch $DEVSTACK_BRANCH && \
    git clone git://git.openstack.org/openstack/requirements --branch $DEVSTACK_BRANCH /opt/stack/requirements && \
    for \
        PROJECT in $PROJECTS; \
    do \
        git clone \
            git://git.openstack.org/openstack/$PROJECT.git \
            /opt/stack/$PROJECT \
            --branch $PROJECTS_BRANCH \
            --depth 1 \
            --single-branch; \
    done

# Pre-Install DevStack System Dependencies to Speedup Docker Run
RUN /devstack/tools/install_prereqs.sh \
    # Install Additional Packages MySQL and RabbitMQ
    #  - TODO: Find all needed packages in $(grep --no-filename NOPRIME /devstack/files/apts/* | sed '/dist/d; s/\s*#.*//;')
    #  - TODO: If everything is actually in place, we could set OFFLINE=True in local.conf
    && echo 'mysql-server mysql-server/root_password password secret' | debconf-set-selections \
    && echo 'mysql-server mysql-server/root_password_again password secret' | debconf-set-selections \
    && apt-get update && apt-get --assume-yes --no-install-recommends install \
        mysql-server \
        rabbitmq-server \
    && service mysql start \
    # Cleanup
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install external pip, resolving missing python-setuptools and wheel errors
RUN curl --silent --show-error https://bootstrap.pypa.io/get-pip.py | python

# Solve dependency conflict for urllib3 with pre-installed requests
RUN pip install --upgrade --force-reinstall requests

# Install known working Python packages
RUN pip install \
        --no-cache-dir \
        --constraint  /opt/stack/requirements/upper-constraints.txt \
        --requirement /opt/stack/requirements/global-requirements.txt \
        --requirement /opt/stack/requirements/test-requirements.txt

# Setup non-Root user "stack", as required by stack.sh
RUN useradd --shell /bin/bash --home-dir /opt/stack/ stack \
    && echo "stack ALL=(ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/stack \
    && sudo chown --recursive stack /devstack/

# Copy DevStack configuration, if file has changed
COPY local.conf /devstack/

# This container starts systemd, so do not add an additional Docker CMD!
# Place any post-start calls in the Makefile.

# Actual DevStack setup has to happen in a running container,
# because of missing privileges during Docker build.

# Thats's right, we add ARGs and dependent labels at the end, because they will change on every build
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL org.label-schema.build-date=$BUILD_DATE \
        org.label-schema.name="DockStack" \
        org.label-schema.description="Docker on DevStack on Docker" \
        org.label-schema.version=$VERSION-$BUILD_DATE-git-$VCS_REF \
        org.label-schema.vendor="Jan Mattfeld" \
        org.label-schema.vcs-url="https://github.com/janmattfeld/DockStack" \
        org.label-schema.vcs-ref=$VCS_REF \
        org.label-schema.docker.cmd="docker run --privileged --detach devstack " \
        org.label-schema.docker.params="DEVSTACK_BRANCH, PROJECTS_BRANCH, PROJECTS" \
        org.label-schema.schema-version="1.0"
