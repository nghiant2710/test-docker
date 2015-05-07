# This file describes the standard way to build Docker, using docker
#
# Usage:
#
# # Assemble the full dev environment. This is slow the first time.
# docker build -t docker .
#
# # Mount your source in an interactive container for quick testing:
# docker run -v `pwd`:/go/src/github.com/docker/docker --privileged -i -t docker bash
#
# # Run the test suite:
# docker run --privileged docker hack/make.sh test
#
# # Publish a release:
# docker run --privileged \
#  -e AWS_S3_BUCKET=baz \
#  -e AWS_ACCESS_KEY=foo \
#  -e AWS_SECRET_KEY=bar \
#  -e GPG_PASSPHRASE=gloubiboulga \
#  docker hack/release.sh
#
# Note: Apparmor used to mess with privileged mode, but this is no longer
# the case. Therefore, you don't have to disable it anymore.
#

FROM ubuntu:14.04
# This file describes the standard way to cross building Docker, using docker
#
# Usage:
#
# # Assemble the full dev environment. This is slow the first time.
# head -n -2 Dockerfile > .DockerfileCross.swp
# cat Dockerfile.cross >> .DockerfileCross.swp
# tail -n 2 Dockerfile >> .DockerfileCross.swp
# docker build -t dockercross -f DockerfileCross.swp
#
# # Mount your source in an interactive container for quick testing:
# docker run -v `pwd`:/go/src/github.com/docker/docker --privileged -i -t dockercross bash
#

MAINTAINER Praneeth Bodduluri <lifeeth@resin.io>

# Packaged dependencies
RUN apt-get update && apt-get install -y \	
	libc6-dev-armel-armhf-cross \
	gcc-arm-linux-gnueabi \
	gcc-multilib \
	git-core \
	ca-certificates \
	build-essential \
	curl \
	libacl1-dev \
	libapparmor-dev \
	libblkid-dev \
	liblzo2-dev \
	libsqlite3-dev \
	zlib1g-dev \
	btrfs-tools \
	e2fslibs-dev \
	libdevmapper-dev \
	apparmor \
	aufs-tools \
	mercurial \
	ruby1.9.1 \
	ruby1.9.1-dev \
	s3cmd=1.1.0* \
	--no-install-recommends

# Get lvm2 source for compiling statically
RUN git clone -b v2_02_103 https://git.fedorahosted.org/git/lvm2.git /usr/local/lvm2
# see https://git.fedorahosted.org/cgit/lvm2.git/refs/tags for release tags

# Compile and install lvm for linux/arm and linux/i386
RUN cd /usr/local/lvm2 \
	&& export ac_cv_func_malloc_0_nonnull=yes \
	&& ./configure --enable-static_link --host=arm-linux-gnueabi --prefix=/usr/arm-linux-gnueabi/ \
	&& make device-mapper \
	&& make install_device-mapper
RUN cd /usr/local/lvm2 \
	&& make clean && export ac_cv_func_malloc_0_nonnull=yes \
	&& ./configure --build=i686-pc-linux-gnu "CFLAGS=-m32" "CXXFLAGS=-m32" "LDFLAGS=-m32" --prefix=/usr/lib32/ --enable-static_link \
	&& make device-mapper \
	&& make install_device-mapper

# Compile and install sqlite3 for linux/arm and linux/i386
ENV SQLITE3_VERSION 3080803
RUN mkdir -p /usr/src/sqlite3 \
	&& curl -sSL http://www.sqlite.org/2015/sqlite-autoconf-${SQLITE3_VERSION}.tar.gz | tar -v -C /usr/src/sqlite3 -xz --strip-components=1
RUN cd /usr/src/sqlite3 \
	&& ./configure --host=arm-linux-gnueabi --prefix=/usr/arm-linux-gnueabi/ \
	&& make \
	&& make install
RUN cd /usr/src/sqlite3 \
	&& make clean && ./configure --build=i686-pc-linux-gnu "CFLAGS=-m32" "CXXFLAGS=-m32" "LDFLAGS=-m32" --prefix=/usr/lib32/ \
	&& make \
	&& make install

# Compile and install libapparmor for linux/arm and linux/i386
ENV LIBAPPARMOR_VERSION 2.9
ENV LIBAPPARMOR_PATCH 1
RUN mkdir -p /usr/src/apparmor \
	&& curl -sSL https://launchpad.net/apparmor/${LIBAPPARMOR_VERSION}/${LIBAPPARMOR_VERSION}.${LIBAPPARMOR_PATCH}/+download/apparmor-${LIBAPPARMOR_VERSION}.${LIBAPPARMOR_PATCH}.tar.gz | tar -v -C /usr/src/apparmor -xz --strip-components=1
RUN cd /usr/src/apparmor/libraries/libapparmor \
	&& ./configure --host=arm-linux-gnueabi --prefix=/usr/arm-linux-gnueabi/ \
	&& make \
	&& make install
RUN cd /usr/src/apparmor/libraries/libapparmor \
	&& make clean && ./configure --build=i686-pc-linux-gnu "CFLAGS=-m32" "CXXFLAGS=-m32" "LDFLAGS=-m32" --prefix=/usr/lib32/ \
	&& make \
	&& make install

# Compile Go for cross compilation
ENV DOCKER_CROSSPLATFORMS \
	linux/386 linux/arm \
	darwin/amd64 darwin/386 \
	freebsd/amd64 freebsd/386 freebsd/arm \
	windows/amd64 windows/386

# Install Go
ENV GO_VERSION 1.4.2
RUN curl -sSL https://golang.org/dl/go${GO_VERSION}.src.tar.gz | tar -v -C /usr/local -xz \
	&& mkdir -p /go/bin
ENV PATH /go/bin:/usr/local/go/bin:$PATH
ENV GOPATH /go:/go/src/github.com/docker/docker/vendor

# (set an explicit GOARM of 5 for maximum compatibility)
ENV PATH /go/bin:$PATH
ENV GOARM 6
RUN cd /usr/local/go/src \
	&& set -x \
	&& for platform in $DOCKER_CROSSPLATFORMS; do \
		GOOS=${platform%/*} \
		GOARCH=${platform##*/} \
			./make.bash --no-clean 2>&1; \
	done
	
# Get btrfs-tools
RUN git clone --no-checkout git://git.kernel.org/pub/scm/linux/kernel/git/kdave/btrfs-progs.git && cd /btrfs-progs && git checkout -q v3.17.3
# see https://git.kernel.org/cgit/linux/kernel/git/kdave/btrfs-progs.git/refs/tags for release tags

# Compile and install btrfs-tools
RUN	cd /btrfs-progs && make -j $(nproc) DISABLE_DOCUMENTATION=1 && make install DISABLE_DOCUMENTATION=1
# see https://git.kernel.org/cgit/linux/kernel/git/kdave/btrfs-progs.git/tree/INSTALL

# Grab Go's cover tool for dead-simple code coverage testing
RUN	go get code.google.com/p/go.tools/cmd/cover

# TODO replace FPM with some very minimal debhelper stuff
RUN	gem install --no-rdoc --no-ri fpm --version 1.3.2

# Install man page generator
RUN mkdir -p /go/src/github.com/cpuguy83 \
    && git clone -b v1 https://github.com/cpuguy83/go-md2man.git /go/src/github.com/cpuguy83/go-md2man \
    && cd /go/src/github.com/cpuguy83/go-md2man \
    && go get -v ./...

# Set user.email so crosbymichael's in-container merge commits go smoothly
RUN git config --global user.email 'docker-dummy@example.com'

# Add an unprivileged user to be used for tests which need it
RUN groupadd -r docker
RUN useradd --create-home --gid docker unprivilegeduser

VOLUME	/var/lib/docker
WORKDIR	/go/src/github.com/docker/docker
ENV	DOCKER_BUILDTAGS	apparmor selinux

# Set an explicit BUILD_CROSS variable so that the hack/make.sh cross uses this specific paths set in this Dockerfile for C libraries
ENV BUILD_CROSS 1

# Wrap all commands in the "docker-in-docker" script to allow nested containers
ENTRYPOINT ["hack/dind"]

# Upload docker source
COPY . /go/src/github.com/docker/docker
