# STAGE 1: Build
# Insight 7.3.50.20110803-cvs, the version shipped with the Windows BMDE (devkitPro's arm-eabi-insight), built from
# its original sources (see scripts/fetch_source.sh). Ubuntu 14.04 provides a toolchain of the same era, so the 2011
# code (GDB, Tcl/Tk 8.4, itcl 3.3) builds without patches.
FROM ubuntu:14.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    bison \
    flex \
    m4 \
    texinfo \
    libncurses5-dev \
    libexpat1-dev \
    zlib1g-dev \
    libx11-dev \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

COPY src/insight-7.3.50.20110803-cvs.tar.xz /src/
WORKDIR /src
RUN tar -xJf insight-7.3.50.20110803-cvs.tar.xz && mkdir build

# Same target as the Windows build (arm-eabi-insight, arm-eabi-gdb, arm-eabi-run). Docs are skipped (MAKEINFO=true)
# because the texinfo of this toolchain is newer than the one of the sources
WORKDIR /src/build
RUN ../insight-7.3.50.20110803-cvs/configure \
      --prefix=/opt/insight \
      --target=arm-eabi \
      --disable-werror \
      --disable-nls \
      --with-expat \
      --without-python \
    && make -j"$(nproc)" MAKEINFO=true \
    && make install MAKEINFO=true \
    && strip --strip-unneeded /opt/insight/bin/*


# STAGE 2: Runtime
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Runtime libraries of Insight, gdb-multiarch as alternative debugger, and X11 / VNC utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    libx11-6 \
    libncurses5 \
    libtinfo5 \
    zlib1g \
    libexpat1 \
    gdb-multiarch \
    x11vnc \
    xvfb \
    xfonts-base \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/insight /opt/insight
# Not symlinked: Tcl finds its library relative to the path of the executable
ENV PATH="/opt/insight/bin:${PATH}"
RUN printf '#!/bin/sh\nexec /opt/insight/bin/arm-eabi-insight "$@"\n' > /usr/local/bin/insight \
    && chmod +x /usr/local/bin/insight

COPY tcl/connect.tcl /opt/insight-docker/connect.tcl
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN export uid=1000 gid=1000 username=insight && \
    mkdir -p /home/${username} /input && \
    echo "${username}:x:${uid}:${gid}:${username},,,:/home/${username}:/bin/bash" >> /etc/passwd && \
    echo "${username}:x:${uid}:" >> /etc/group && \
    chown ${uid}:${gid} -R /home/${username}

USER insight
ENV HOME=/home/insight
WORKDIR /input

ENTRYPOINT ["/entrypoint.sh"]
CMD []
