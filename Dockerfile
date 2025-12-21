# STAGE 1: Build
FROM ubuntu:22.04 AS builder

# Prevent interactive prompts during apt install
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    autoconf automake autogen tk-dev tcl-dev libgmp-dev \
    libmpfr-dev texinfo bison flex git build-essential \
    && rm -rf /var/lib/apt/lists/*

# Clone and build Insight
WORKDIR /src
RUN git clone --depth 1 git://sourceware.org/git/insight.git --recursive

WORKDIR /src/insight
RUN autoconf && autoupdate

# Using the configuration provided in your snippet
RUN ./configure \
    --prefix=/usr/local \
    --libdir=/usr/lib64 \
    --disable-binutils \
    --disable-elfcpp \
    --disable-gas \
    --disable-gold \
    --disable-gprof \
    --disable-ld \
    --disable-rpath \
    --disable-zlib \
    --enable-sim \
    --with-gdb-datadir=/usr/share/insight \
    --with-jit-reader-dir=/usr/lib64/insight \
    --with-separate-debug-dir='/usr/lib/debug' \
    --with-expat \
    --without-libunwind \
    --without-isl \
    --without-python

RUN make -j$(nproc)
RUN make install

# STAGE 2: Runtime
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies (Tcl/Tk, itcl, itk, etc.)
RUN apt-get update && apt-get install -y \
    itcl3 \
    itk3 \
    iwidgets4 \
    libgmp10 \
    libmpfr6 \
    libexpat1 \
    && rm -rf /var/lib/apt/lists/*

# Copy the compiled binaries and data from the builder stage
COPY --from=builder /usr/local /usr/local
COPY --from=builder /usr/lib64 /usr/lib64
COPY --from=builder /usr/share/insight /usr/share/insight

# Set environment variable for the display
ENV DISPLAY=:0

# Start insight by default
ENTRYPOINT ["insight"]