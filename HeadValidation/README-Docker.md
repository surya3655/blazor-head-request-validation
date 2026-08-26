README: Running HeadValidation in Docker / Rancher Desktop
=====================================================

This document shows how to build and run the HeadValidation sample inside a container
using Rancher Desktop's Docker (`docker.exe`) or `nerdctl`/`podman` where available.

Prerequisites
-
- Rancher Desktop installed (or Docker Desktop / Podman). On Windows the Rancher
  Desktop Docker shim is commonly at:

  C:\Users\SuryaElayaperumal\AppData\Local\Programs\Rancher Desktop\resources\resources\win32\bin\docker.exe

- .NET SDK 11 preview (for local builds and `dotnet watch` during development).
- `kubectl` if you plan to deploy to the Rancher Desktop Kubernetes cluster.

Build the image (Rancher Desktop / docker)
-
From the repository root (where `Dockerfile` is located):

PowerShell example (explicit path to Rancher Desktop docker):

```powershell
& "C:\Users\SuryaElayaperumal\AppData\Local\Programs\Rancher Desktop\resources\resources\win32\bin\docker.exe" build -t headvalidation:latest -f Dockerfile .
```

Or, if Rancher Desktop exposes `docker` on PATH:

```powershell
docker build -t headvalidation:latest -f Dockerfile .
```

Run the container (Static SSR)
-
```powershell
docker run --rm --name headvalidation_static -e ASPNETCORE_URLS="http://+:8080" -e RenderMode=StaticSsr -p 8080:8080 headvalidation:latest
```

Run the container (InteractiveServer)
-
```powershell
docker run --rm --name headvalidation_interactive -e ASPNETCORE_URLS="http://+:5181" -e RenderMode=InteractiveServer -p 5181:5181 headvalidation:latest
```

Smoke tests
-
From host:

```powershell
curl.exe -I http://localhost:8080/plain
curl.exe -I http://localhost:8080/teapot
curl.exe -s -o NUL -D - http://localhost:8080/slow
```

Collecting evidence
-
- Run the test harness against the running container (adjust `-BaseUrl`):

```powershell
.\scripts\Test-HeadEndpoints.ps1 -BaseUrl http://localhost:8080 -OutDir artifacts/container-run
```

- Logs: `docker logs headvalidation_static` (or use `--since` to limit output)

Kubernetes (Rancher Desktop) notes
-
- To use the locally built image in Rancher Desktop k8s, set `imagePullPolicy: Never`
  in your manifest or push the image to a registry the cluster can reach.

Hot reload
-
- `dotnet watch` is a local development feature. To hot-reload inside a container, mount
  the project folder into an SDK image and run `dotnet watch` inside that container:

```powershell
docker run --rm -it -v ${PWD}:/src -w /src mcr.microsoft.com/dotnet/sdk:11.0-preview pwsh -c "dotnet watch --launch-profile StaticSsr"
```

Caveats and tips
-
- Data protection keys inside the container are stored in `/root/.aspnet/DataProtection-Keys`.
  These will be lost when the container is removed; for production use mount a persistent volume
  or configure an encrypted key store.
- If you see Razor parse errors during `dotnet watch`, fix the Razor file syntax and re-run the
  watch command.

Files referenced
-
- `Dockerfile` — multi-stage publish and runtime image
- `scripts/Test-HeadEndpoints.ps1` — test harness used to generate artifacts
- Artifact evidence after a container run: `artifacts/container-run/` (create by running the script)

If you want, I can:
- Create a `k8s/deploy.yaml` in the repo (with `imagePullPolicy: Never`).
- Update `scripts/Test-HeadEndpoints.ps1` to add a `-Container` mode that builds the image, runs it, and collects artifacts automatically.
