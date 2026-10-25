# Containerization threaded-cgroup reproducer

`LinuxContainer.stop()` fails with errno 95 (`EOPNOTSUPP`) when a container leaves an empty threaded child cgroup. The same test with an ordinary domain child succeeds.

```sh
make reproduce
```

The test uses Containerization 0.53.0, its official guest image, and two Alpine 3.22 containers with networking disabled. Each container creates an empty child cgroup and exits with code 0. The host then calls `stop()` once.

Observed output:

```text
domain: stop() succeeded
threaded: REPRODUCED: ... errno 95: failed to write to .../nested/cgroup.kill ...
```

The VM stops, but `stop()` throws and leaves the container object errored. This can interrupt application shutdown or follow-up cleanup.

The binary exits 1 when the bug reproduces, 0 if both cases pass, or 2 for an unrelated failure. Make reports `Error 1` and exits 2 when the bug reproduces.

The first run downloads dependencies, images, and the default kernel. Test VMs and their backing files are removed afterward; downloads stay cached.

[Recorded output and environment](verification.log).
