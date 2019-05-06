FROM centos:latest AS build

ARG VERSION
ARG GO_VERSION
ARG NDCTL_VERSION
ARG NDCTL_CONFIGFLAGS
ARG NDCTL_BUILD_DEPS
#pull dependencies required for downloading and building libndctl
RUN yum update; \
    yum install -y ${NDCTL_BUILD_DEPS} make; \
    yum clean all

WORKDIR /
RUN wget https://github.com/pmem/ndctl/archive/v${NDCTL_VERSION}.tar.gz
RUN tar zxvf v${NDCTL_VERSION}.tar.gz && mv ndctl-${NDCTL_VERSION} ndctl
WORKDIR /ndctl
RUN ./autogen.sh
RUN ./configure ${NDCTL_CONFIGFLAGS}
RUN make install

#setup go dev environment
RUN wget https://dl.google.com/go/go$GO_VERSION.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:$PATH"
ENV PKG_CONFIG_PATH="/usr/lib/pkgconfig"


# build pmem-vgm
ADD . /go/src/github.com/intel/pmem-csi
WORKDIR /go/src/github.com/intel/pmem-csi
ENV GOPATH=/go
RUN make pmem-vgm VERSION=${VERSION}
RUN mkdir -p /go/bin
RUN mv ./_output/pmem-vgm /go/bin/

# build clean container
FROM centos:latest
RUN yum update; \
    yum install -y lvm2; \
    yum clean all
LABEL maintainers="Intel"
LABEL description="Pmem CSI driver volume group manager"

# default lvm config is using lvmeated and throwing below warning for all lvm tools
# WARNING: Failed to connect to lvmetad. Falling back to device scanning.
# So we disable the lvmetad in config.
# https://bugs.launchpad.net/ubuntu/+source/initramfs-tools/+bug/1768230
RUN sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf

# move required binaries and libraries to clean container
COPY --from=build /usr/lib/libndctl* /usr/lib/
COPY --from=build /usr/lib/libdaxctl* /usr/lib/
RUN mkdir -p /go/bin
COPY --from=build /go/bin/pmem-vgm /go/bin/

ENV LD_LIBRARY_PATH=/usr/lib
ENTRYPOINT ["/go/bin/pmem-vgm"]
