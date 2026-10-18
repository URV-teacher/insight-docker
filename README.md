# insight-docker
Insight, the graphical frontend for GDB developed by Red Hat, packaged in Docker to debug Nintendo DS programs running
in [DeSmuME](https://github.com/URV-teacher/desmume-docker) through its GDB stub. It also contains `gdb-multiarch` as
an alternative terminal debugger.

It is used by the `bmde debug` command of [bmde](https://github.com/URV-teacher/bmde), but can be used on its own.

## Version and sources
The image contains the same Insight shipped with the Windows BMDE (`devkitPro/insight/bin/arm-eabi-insight.exe`):
**GDB/Insight 7.3.50.20110803-cvs** for the `arm-eabi` target, with Tcl/Tk 8.4.1, itcl/itk 3.3.0 and iwidgets 4.0.1.

That version was built by devkitPro from a checkout of the CVS repository of sourceware.org (it was never released as a
tarball). [`scripts/fetch_source.sh`](scripts/fetch_source.sh) reconstructs that checkout from the CVS repository, which
sourceware.org still serves through rsync, and packs it into
[`src/insight-7.3.50.20110803-cvs.tar.xz`](src) (SHA-256
`b8bfa5e5b0b42c50faa9164b092565e8ff3907f7eee465194f2a267b421979d6`), which is the source used to build the image:

* The Windows binary reports GDB `7.3.50.20110803-cvs` and BFD `2.21.53.20110801`, and was linked on 2011-08-04 01:13
  UTC. Since both version strings were bumped daily at 00:00 UTC, `gdb/` (including the Insight GUI, `gdb/gdbtk`) is
  taken as of 2011-08-03 and `bfd/`, `opcodes/` and `include/` as of 2011-08-01. Between both dates, these only changed
  in PowerPC, MIPS, Mach-O and x86 code, irrelevant for ARM.
* All the 211 files of the Tcl library of the Windows Insight (`share/insight1.0`) are identical to the ones of the
  reconstructed source.
* The only patch of devkitPro for GDB in those years changed how dependencies are tracked when building with MinGW, so
  the sources are built without patches.

The 2011 code is built with the toolchain of Ubuntu 14.04 (GCC 4.8), which builds it without patches, and runs on
Ubuntu 22.04.

## Usage
Mount the project to debug (the folder with the `.elf`) as working directory, in the same path where it was built so the
debugger finds the source code (`bmde build` builds projects in `/input/<project folder>`), and give the address of the
GDB stub in `GDB_TARGET`. For example, with DeSmuME running in a container named `desmume` with `--arm9gdb=1024`, in the
Docker network `bmde-debug`:

```bash
docker run --rm -it --network bmde-debug \
  -v "$PWD:/input/$(basename "$PWD"):ro" -w "/input/$(basename "$PWD")" \
  -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY="$DISPLAY" \
  -v "$XAUTHORITY:/tmp/.docker.xauth:ro" -e XAUTHORITY=/tmp/.docker.xauth \
  -e MODE=host -e GDB_TARGET=desmume:1024 \
  aleixmt/insight
```

With Insight, press the **Run** button to connect to `GDB_TARGET`: as if "Remote/TCP" had been chosen in the target
selection dialog, the program is downloaded, stops at `main` and can be debugged from there. With `gdb-multiarch` or
`arm-eabi-gdb`, the debugger starts already connected to `GDB_TARGET`.

The ELF to debug (and other arguments of the debugger) can be given as arguments of the container. If none is given,
the first `.elf` of the working directory is used.

| Variable          | Default   | Description                                                                          |
|-------------------|-----------|--------------------------------------------------------------------------------------|
| `DEBUGGER`        | `insight` | `insight`, `arm-eabi-gdb` (the terminal GDB of the same build) or `gdb-multiarch`.   |
| `GDB_TARGET`      |           | `HOST:PORT` of the GDB stub to debug. If empty, the debugger does not connect.       |
| `WAIT_FOR_TARGET` | `60`      | Seconds to wait for `GDB_TARGET` to accept connections before starting the debugger. |
| `MODE`            | `none`    | `host` (X11 of the host, needs `DISPLAY` and `XAUTHORITY`), `vnc` or `none`.         |
| `VNC_PORT`        | `5900`    | Port of the VNC server in `vnc` mode. Also `VNC_PASSWORD`, `VNC_GEOMETRY`.           |

Insight saves its preferences, sessions and breakpoints in `/home/insight/.gdbtkinit`; mount a volume in
`/home/insight` to keep them.

## Build
```bash
docker build -t aleixmt/insight .
```

To regenerate the source tarball from the CVS repository of sourceware.org (downloads ~900 MB):

```bash
scripts/fetch_source.sh src/insight-7.3.50.20110803-cvs.tar.xz
```
