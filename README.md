# docker-busybox-httpd

Statically compiled BusyBox only containing httpd. It is a minimal static web server image, published to `ghcr.io/trexx/docker-busybox-httpd`, that serves whatever is mounted at `/www`.

## Overview

The [Dockerfile](Dockerfile) builds BusyBox from source and copies the result into an empty image:

- `build-busybox` (`alpine:3.24`) installs `gcc`, `musl-dev`, `make` and `perl`, downloads `busybox-<BUSYBOX_VERSION>.tar.bz2` from busybox.net (currently `1.38.0`) and builds it with the [`.config`](.config) in this repository. That config builds a static binary with only the `httpd` applet enabled, with range requests, gzip, ETag, Last-Modified and Date support; CGI, basic auth and proxying are disabled. The stage also creates a `static` user and downloads [catatonit](https://github.com/openSUSE/catatonit).
- The final image is `FROM scratch` and contains only `/etc/passwd`, `/busybox` and `/catatonit`.

The image runs as uid/gid `1000:1000` (the `static` user), numeric so Kubernetes' `runAsNonRoot` can verify it. The working directory is `/www`. The entrypoint is `/catatonit --` and the command is `/busybox httpd -f -p 8080`, so httpd runs in the foreground and serves `/www` on port 8080. With gzip support, httpd serves a pre-compressed `<file>.gz` to clients that accept gzip, which lets data-only images ship pre-gzipped files. catatonit is the x86_64 build.

## Usage

Images are published as `ghcr.io/trexx/docker-busybox-httpd:<version>` and `ghcr.io/trexx/docker-busybox-httpd:latest`, where the version is the BusyBox version (for example `1.38.0`).

Mount the files to serve at `/www` and expose port 8080:

```sh
docker run --rm -p 8080:8080 -v "$PWD/site:/www:ro" ghcr.io/trexx/docker-busybox-httpd:latest
```

In Kubernetes it is used as the web server for data-only images such as [docker-homer](https://github.com/trexx/docker-homer) and [docker-acestream-webplayer](https://github.com/trexx/docker-acestream-webplayer): the site image is mounted as an image volume at `/www`.

```yaml
spec:
  containers:
    - name: web
      image: ghcr.io/trexx/docker-busybox-httpd:<version>
      ports:
        - name: http
          containerPort: 8080
      volumeMounts:
        - name: www
          mountPath: /www
  volumes:
    - name: www
      image:
        reference: ghcr.io/trexx/<site-image>:<version>
```

## Configuration

The httpd options are the image's command, `/busybox httpd -f -p 8080`; override the command to change them, for example the port. Which httpd features are available is fixed at build time by [`.config`](.config).

## Development

Build the image locally with:

```sh
docker build .
```

The Dockerfile uses `ADD --chmod`, which needs BuildKit (the default builder in current Docker). To change the BusyBox features, edit `.config`, the BusyBox build configuration the Dockerfile copies in before `make`.

Dependency updates:

- [Renovate](.github/renovate.json) updates `BUSYBOX_VERSION` and `CATATONIT_VERSION` through the `# renovate:` comments above them in the Dockerfile, and the Alpine base image. BusyBox versions come from a custom datasource that reads `https://busybox.net/downloads/`; those updates are not automerged.

Workflows in `.github/workflows`:

- `container-check.yml` runs hadolint on the Dockerfile and builds the image without pushing it, on pull requests and pushes to `main`.
- `trivy.yml` scans `ghcr.io/trexx/docker-busybox-httpd:latest` daily and uploads the results to the repository's Security tab.

## Releases

Releases are cut with the Release button: Actions → Release → Run workflow ([`.github/workflows/release.yml`](.github/workflows/release.yml), which calls `trexx/actions`' `release-image.yml`). Run it from the default branch.

1. It works out the tag from `BUSYBOX_VERSION` in the Dockerfile, for example `1.38.0`. If that version was released before, it uses `<version>-N` for the rebuild (for example after a base image update). A tag can also be given by hand in the `tag` input.
2. It builds the image and pushes it as that tag and `latest`.
3. It creates the git tag and the GitHub release.

Ticking "dry run" only works out the tag and builds the image; nothing is pushed and no release is created. Old images are pruned from the package after a push (`latest` and the newest tagged images are kept).

Pushing a tag by hand (matching `*.*.*`) still works: [`.github/workflows/build.yml`](.github/workflows/build.yml) builds and pushes the image for that tag.
