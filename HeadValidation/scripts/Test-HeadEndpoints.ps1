[CmdletBinding()]
param(
    [string] $BaseUrl = "http://localhost:5180",
    [string] $EvidenceDirectory = "",
    [switch] $Container,
    [string] $DockerExe = "docker",
    [string] $ImageName = "headvalidation:latest",
    [string] $ContainerName = "headvalidation_test",
    [int] $ContainerPort = 8080,
    [string] $RenderMode = "StaticSsr"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http

$routes = [ordered]@{
    "plain"         = @{ Path = "/plain"; Status = 200 }
    "item-42"       = @{ Path = "/item/42"; Status = 200 }
    "slow"          = @{ Path = "/slow"; Status = 200 }
    "secure"        = @{ Path = "/secure"; Status = 302 }
    "teapot"        = @{ Path = "/teapot"; Status = 418 }
    "missing-route" = @{ Path = "/missing-route"; Status = 404 }
    "logo.png"      = @{ Path = "/logo.png"; Status = 200 }
}

if (-not $EvidenceDirectory -or $EvidenceDirectory -eq "") {
    if ($PSScriptRoot -and $PSScriptRoot -ne "") {
        $EvidenceDirectory = (Join-Path $PSScriptRoot "..\artifacts\head-validation")
    } else {
        $EvidenceDirectory = (Join-Path (Get-Location).Path "artifacts\head-validation")
    }
}

if ($Container) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $EvidenceDirectory = Join-Path (Join-Path (Split-Path $EvidenceDirectory -Parent) "") "container-run-$timestamp"
}

New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null
$handler = [System.Net.Http.HttpClientHandler]::new()
$handler.AllowAutoRedirect = $false
$client = [System.Net.Http.HttpClient]::new($handler)
$client.BaseAddress = [Uri]::new($BaseUrl)

function Invoke-Docker {
    param($Args)
    $exe = $DockerExe
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) {
        if (-not (Test-Path $exe)) { throw "Docker executable '$exe' not found on PATH or as file." }
    }
    try {
        $out = & $exe @Args 2>&1 | Out-String
    } catch {
        # Return the error text instead of terminating
        $out = $_.Exception.Message
    }
    return $out
}

try {
    if ($Container) {
        Write-Host "Building image $ImageName using '$DockerExe'..."
        $buildArgs = @('build','-t',$ImageName,'-f','Dockerfile','.')
        $buildOut = Invoke-Docker $buildArgs 2>&1
        $buildOut | Set-Content (Join-Path $EvidenceDirectory "docker-build.log")

        Write-Host "Running container $ContainerName (RenderMode=$RenderMode) on port $ContainerPort..."
        $portMap = "$($ContainerPort):$($ContainerPort)"
        $runArgs = @('run','-d','--name',$ContainerName,'-e',"ASPNETCORE_URLS=http://+:$ContainerPort",'-e',"RenderMode=$RenderMode",'-p',$portMap,$ImageName)
        $containerId = Invoke-Docker $runArgs | Out-String
        $containerId = $containerId.Trim()
        if (-not $containerId) { throw "Failed to start container $ContainerName." }

        # set BaseUrl to container endpoint on localhost
        $BaseUrl = "http://localhost:$ContainerPort"
        $client.BaseAddress = [Uri]::new($BaseUrl)
        # wait for the container to become ready (poll /plain)
        $maxWait = 20
        $waited = 0
        $ready = $false
        while ($waited -lt $maxWait) {
            try {
                $resp = & curl.exe -s -I "$BaseUrl/plain" 2>$null
                if ($LASTEXITCODE -eq 0 -and $resp) { $ready = $true; break }
            } catch {}
            Start-Sleep -Seconds 1
            $waited++
        }
        if (-not $ready) { Write-Warning "Container did not respond at $BaseUrl/plain after $maxWait seconds." }
    }
    foreach ($name in $routes.Keys) {
        $path = $routes[$name].Path
        $expectedStatus = $routes[$name].Status
        $headHeaders = & curl.exe -sS -I "$BaseUrl$path"
        $getHeaders = & curl.exe -sS -o NUL -D - "$BaseUrl$path"
        $headHeaders | Set-Content (Join-Path $EvidenceDirectory "$name.head.headers.txt")
        $getHeaders | Set-Content (Join-Path $EvidenceDirectory "$name.get.headers.txt")

        $headRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, $path)
        $head = $client.SendAsync($headRequest).GetAwaiter().GetResult()
        $get = $client.GetAsync($path).GetAwaiter().GetResult()
        $headBody = $head.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()

        if ([int] $head.StatusCode -ne $expectedStatus) {
            throw "HEAD $path returned $([int] $head.StatusCode); expected $expectedStatus."
        }
        if ($head.StatusCode -ne $get.StatusCode) {
            throw "HEAD $path returned $([int] $head.StatusCode), but GET returned $([int] $get.StatusCode)."
        }
        if ($headBody.Length -ne 0) {
            throw "HEAD $path returned a $($headBody.Length)-byte body."
        }
        if ([int] $head.StatusCode -eq 405) {
            throw "HEAD $path returned 405 Method Not Allowed."
        }

        Write-Host "PASS  $path  $([int] $head.StatusCode)"
        $headRequest.Dispose()
        $head.Dispose()
        $get.Dispose()
    }

    $plainRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, "/plain")
    $plainHead = $client.SendAsync($plainRequest).GetAwaiter().GetResult()
    if ($plainHead.Content.Headers.ContentType.ToString() -ne "text/html; charset=utf-8") {
        throw "HEAD /plain returned Content-Type '$($plainHead.Content.Headers.ContentType)'."
    }
    $plainRequest.Dispose()
    $plainHead.Dispose()

    $teapotRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, "/teapot")
    $teapotHead = $client.SendAsync($teapotRequest).GetAwaiter().GetResult()
    if (-not $teapotHead.Headers.Contains("X-Test") -or $teapotHead.Headers.GetValues("X-Test") -notcontains "hello") {
        throw "HEAD /teapot did not preserve X-Test: hello."
    }
    $teapotRequest.Dispose()
    $teapotHead.Dispose()

    $hitsBefore = [long] $client.GetStringAsync("/hits").GetAwaiter().GetResult()
    $hitRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, "/plain")
    $hitHead = $client.SendAsync($hitRequest).GetAwaiter().GetResult()
    $hitRequest.Dispose()
    $hitHead.Dispose()
    $hitsAfter = [long] $client.GetStringAsync("/hits").GetAwaiter().GetResult()
    @("before=$hitsBefore", "after=$hitsAfter") | Set-Content (Join-Path $EvidenceDirectory "hits.txt")
    if ($hitsAfter -ne $hitsBefore + 1) {
        throw "HEAD /plain changed /hits from $hitsBefore to $hitsAfter; expected exactly one render."
    }

    $headTimer = [Diagnostics.Stopwatch]::StartNew()
    $slowRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, "/slow")
    $slowHead = $client.SendAsync($slowRequest).GetAwaiter().GetResult()
    $headTimer.Stop()
    $slowRequest.Dispose()
    $slowHead.Dispose()

    $getTimer = [Diagnostics.Stopwatch]::StartNew()
    $slowGet = $client.GetAsync("/slow").GetAwaiter().GetResult()
    $getTimer.Stop()
    $slowGet.Dispose()
    @("HEAD=$($headTimer.Elapsed.TotalSeconds)", "GET=$($getTimer.Elapsed.TotalSeconds)") |
        Set-Content (Join-Path $EvidenceDirectory "slow.timings.txt")
    if ($headTimer.Elapsed.TotalSeconds -lt 1.8 -or $getTimer.Elapsed.TotalSeconds -lt 1.8) {
        throw "The streaming page did not execute its two-second operation for both HEAD and GET."
    }

    Write-Host "All HEAD endpoint assertions passed. Evidence: $EvidenceDirectory"
}
finally {
    $client.Dispose()
    $handler.Dispose()
    if ($Container) {
        Write-Host "Collecting container logs and cleaning up..."
        try {
            $logsOut = Invoke-Docker @('logs','--since','1m',$ContainerName)
            $logsOut | Set-Content (Join-Path $EvidenceDirectory "container.logs.txt")
            $inspectOut = Invoke-Docker @('inspect',$ImageName)
            $inspectOut | Set-Content (Join-Path $EvidenceDirectory "image.inspect.json")
        } catch {
            Write-Warning "Failed to collect docker logs/inspect: $($_)"
        }
        try {
            Invoke-Docker @('rm','-f',$ContainerName) 2>&1 | Out-Null
        } catch {
            Write-Warning "Failed to remove container $($ContainerName): $($_)"
        }
    }
}