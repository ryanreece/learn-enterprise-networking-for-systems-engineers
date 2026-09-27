# Supported Platforms

Native Linux is the reference platform for the isolated Containerlab labs.
Part A of Lab 01 is separate: it observes a real connection and includes Linux
and Windows PowerShell commands that do not change the host.

## Platform matrix

| Platform | Part A | Part B | Support level |
| --- | --- | --- | --- |
| Ubuntu 24.04 LTS, native | Supported commands documented | Baseline validated | Reference platform; failure-scenario validation is pending. |
| Rocky Linux 9, native | Standard Linux commands apply | Planned | Desirable after Ubuntu validation; not yet tested. |
| Other modern Linux | Standard Linux commands likely apply | Unverified | Use at your own risk and compare kernel, Docker, and Containerlab behavior. |
| macOS | Host observation supported with equivalent tools where available | Linux VM required | Do not treat Docker Desktop alone as native Containerlab support for this course. |
| Windows 11 | PowerShell observation documented | Linux VM recommended | WSL2 is best effort until this repository is tested end to end there. |
| Windows 10 | PowerShell observation documented | Linux VM recommended | Not a reference environment. |

“Baseline validated” means the known-good DNS-to-HTTPS transaction passed. It
does not mean the incomplete failure-scenario lifecycle has passed testing.

## macOS and Windows

Containerlab depends on Linux kernel networking features. For predictable
course behavior, create a Linux VM, install Docker Engine and Containerlab
inside that VM, and clone this repository there.

Upstream Containerlab documents additional [macOS] and [Windows/WSL] options.
Those options may work, but they are not course-supported until the complete
lab lifecycle and every scenario have been tested on them.

## Architecture

The Lab 01 design uses Linux containers and should be capable of supporting
both x86_64 and arm64. Actual multi-architecture image support will be
confirmed when the shared images and topology are implemented. Do not assume
support from this documentation skeleton alone.

## Reporting a platform problem

Include the following with a reproducible report, removing sensitive host and
network details first:

```bash
uname -a
cat /etc/os-release
docker version
docker info
containerlab version
```

Also include the command that failed and its complete error output. Never
include credentials, private keys, or production addresses.

[macOS]: https://containerlab.dev/macos/
[Windows/WSL]: https://containerlab.dev/windows/
