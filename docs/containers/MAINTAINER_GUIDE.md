# Container Maintainer Guide

This document describes how to manage container images for the project.

## Update dependencies

1. Edit [`environment.yml`](../../environment.yml) when dependencies change.
2. Rebuild the development image and save it as a tarball for distribution:
   ```bash
   docker build -t oferta-laboral:dev .
   docker save oferta-laboral:dev | gzip > oferta-laboral-dev.tar.gz
   ```

## Build Apptainer images

- **Local build**
  ```bash
  apptainer build oferta-laboral.sif Singularity.def
  ```
- **CI build**
  The workflow [`singularity-build.yml`](../../.github/workflows/singularity-build.yml) performs the same step in GitHub Actions.

## Testing

Before publishing any image, run the project tests inside the container to ensure the environment works as expected. For example:

```bash
docker run --rm oferta-laboral:dev pytest --maxfail=1 --disable-warnings -q
```
