set -eo pipefail

export DEBIAN_FRONTEND=noninteractive

SRC_DIR="/tmp/insight-src"
INSIGHT_REPO="git://sourceware.org/git/insight.git"

sudo apt-get update
sudo apt-get install -y \
    autoconf \
    automake \
    autogen \
    tk-dev \
    tcl-dev \
    libgmp-dev \
    libmpfr-dev \
    texinfo \
    bison \
    flex \
    git \
    build-essential


rm -rf "${SRC_DIR}"
mkdir -p "${SRC_DIR}"
git clone --depth 1 --recursive "${INSIGHT_REPO}" "${SRC_DIR}"

(
  cd $SRC_DIR

  autoconf
  autoupdate

  ./configure \
      --prefix=/usr/local \
      --libdir=/usr/lib64 \
      --disable-binutils \
      --disable-elfcpp \
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

  make -j"$(nproc)"
  sudo make install
)
