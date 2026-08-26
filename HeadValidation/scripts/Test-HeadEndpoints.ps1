[CmdletBinding()]
param(
    [string] $BaseUrl = "http://localhost:5180",
    [string] $EvidenceDirectory = "./artifacts/head-validation",
    [ValidateSet("StaticSsr", "InteractiveServer")]
    [string] $ExpectedRenderMode
)

$ErrorActionPreference = "Stop"
$baseUri = [Uri]$BaseUrl

if ($baseUri.Scheme -ne "http") {
    throw "Raw HEAD body validation currently requires an HTTP base URL."
}

$evidencePath = [IO.Path]::GetFullPath($EvidenceDirectory)
[IO.Directory]::CreateDirectory($evidencePath) | Out-Null

function Write-Artifact {
    param([string] $Name, [string] $Content)

    [IO.File]::WriteAllText(
        [IO.Path]::Combine($evidencePath, $Name),
        $Content,
        [Text.UTF8Encoding]::new($false))
}

function Invoke-RawHead {
    param([string] $Path, [string] $Name)

    $port = if ($baseUri.IsDefaultPort) { 80 } else { $baseUri.Port }
    $client = [Net.Sockets.TcpClient]::new()
    $client.ReceiveTimeout = 15000
    $client.SendTimeout = 15000

    try {
        $client.Connect($baseUri.Host, $port)
        $stream = $client.GetStream()
        $requestTarget = if ($baseUri.AbsolutePath -eq "/") {
            $Path
        } else {
            $baseUri.AbsolutePath.TrimEnd("/") + $Path
        }
        $request = "HEAD $requestTarget HTTP/1.1`r`nHost: $($baseUri.Authority)`r`nConnection: close`r`n`r`n"
        $requestBytes = [Text.Encoding]::ASCII.GetBytes($request)
        $stream.Write($requestBytes, 0, $requestBytes.Length)

        $buffer = [byte[]]::new(8192)
        $response = [IO.MemoryStream]::new()
        do {
            $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
            if ($bytesRead -gt 0) {
                $response.Write($buffer, 0, $bytesRead)
            }
        } while ($bytesRead -gt 0)

        $responseBytes = $response.ToArray()
        [IO.File]::WriteAllBytes([IO.Path]::Combine($evidencePath, "$Name.head.raw.bin"), $responseBytes)
        $responseText = [Text.Encoding]::GetEncoding(28591).GetString($responseBytes)
        $separatorIndex = $responseText.IndexOf("`r`n`r`n", [StringComparison]::Ordinal)
        if ($separatorIndex -lt 0) {
            throw "HEAD $Path returned no complete HTTP header block."
        }

        $headerText = $responseText.Substring(0, $separatorIndex) + "`r`n"
        $bodyOffset = $separatorIndex + 4
        $bodyLength = $responseBytes.Length - $bodyOffset
        Write-Artifact "$Name.head.headers.txt" $headerText
        Write-Artifact "$Name.head.body-size.txt" "bytes=$bodyLength`n"

        $statusLine = $headerText.Split("`r`n")[0]
        if ($statusLine -notmatch '^HTTP/\d(?:\.\d)?\s+(\d{3})') {
            throw "Could not parse HEAD status from '$statusLine'."
        }

        [pscustomobject]@{
            Status = [int]$Matches[1]
            Headers = $headerText
            BodyLength = $bodyLength
        }
    }
    finally {
        $client.Dispose()
    }
}

function Invoke-Get {
    param([string] $Path, [string] $Name)

    $headersPath = [IO.Path]::Combine($evidencePath, "$Name.get.headers.txt")
    $bodyPath = [IO.Path]::Combine($evidencePath, "$Name.get.body.bin")
    $timing = & curl.exe --silent --show-error --max-time 15 `
        --dump-header $headersPath --output $bodyPath `
        --write-out "status=%{http_code}`ntime=%{time_total}`nsize_download=%{size_download}`n" `
        "$($baseUri.AbsoluteUri.TrimEnd('/'))$Path"
    if ($LASTEXITCODE -ne 0) {
        throw "GET $Path failed with curl exit code $LASTEXITCODE."
    }

    Write-Artifact "$Name.get.timed.txt" ($timing -join "`n")
    $statusLine = [IO.File]::ReadLines($headersPath) | Select-Object -First 1
    if ($statusLine -notmatch '^HTTP/\d(?:\.\d)?\s+(\d{3})') {
        throw "Could not parse GET status from '$statusLine'."
    }

    [pscustomobject]@{
        Status = [int]$Matches[1]
        Headers = [IO.File]::ReadAllText($headersPath)
        Timing = $timing -join "`n"
        BodyPath = $bodyPath
    }
}

function Get-HeaderValue {
    param([string] $Headers, [string] $HeaderName)

    $match = [regex]::Match(
        $Headers,
        "(?im)^$([regex]::Escape($HeaderName)):\s*(.+?)\s*$")
    if ($match.Success) { $match.Groups[1].Value } else { "<absent>" }
}

$routes = @(
    [pscustomobject]@{ Name = "home"; Path = "/"; ExpectedStatus = 200; AssertHeadParity = $true },
    [pscustomobject]@{ Name = "plain"; Path = "/plain"; ExpectedStatus = 200; AssertHeadParity = $true },
    [pscustomobject]@{ Name = "item-42"; Path = "/item/42"; ExpectedStatus = 200; AssertHeadParity = $true },
    [pscustomobject]@{ Name = "slow"; Path = "/slow"; ExpectedStatus = 200; AssertHeadParity = $true },
    [pscustomobject]@{ Name = "slow-teapot"; Path = "/slow-teapot"; ExpectedStatus = 200; AssertHeadParity = $true },
    [pscustomobject]@{ Name = "secure"; Path = "/secure"; ExpectedStatus = 302; AssertHeadParity = $true },
    [pscustomobject]@{ Name = "teapot"; Path = "/teapot"; ExpectedStatus = 418; AssertHeadParity = $true },
    [pscustomobject]@{ Name = "missing-route"; Path = "/missing-route"; ExpectedStatus = 404; AssertHeadParity = $true },
    [pscustomobject]@{ Name = "logo.png"; Path = "/logo.png"; ExpectedStatus = 200; AssertHeadParity = $true },
    [pscustomobject]@{ Name = "hits"; Path = "/hits"; ExpectedStatus = 200; AssertHeadParity = $false },
    [pscustomobject]@{ Name = "login"; Path = "/login"; ExpectedStatus = 200; AssertHeadParity = $false }
)

$failures = [Collections.Generic.List[string]]::new()
$statusRows = [Collections.Generic.List[string]]::new()
$bodyRows = [Collections.Generic.List[string]]::new()
$headerRows = [Collections.Generic.List[string]]::new()
$selectedHeaders = @("Content-Type", "Content-Length", "Location", "X-Test", "ETag", "Last-Modified", "Cache-Control")

foreach ($route in $routes) {
    Write-Host "Testing $($route.Path)"
    $get = Invoke-Get $route.Path $route.Name
    $head = Invoke-RawHead $route.Path $route.Name
    $headTiming = & curl.exe --silent --show-error --max-time 15 --head --output NUL `
        --write-out "status=%{http_code}`ntime=%{time_total}`n" `
        "$($baseUri.AbsoluteUri.TrimEnd('/'))$($route.Path)"
    if ($LASTEXITCODE -ne 0) {
        throw "HEAD $($route.Path) timing request failed with curl exit code $LASTEXITCODE."
    }
    Write-Artifact "$($route.Name).head.timed.txt" (($headTiming -join "`n") + "`n")

    $headCriterion = if ($route.AssertHeadParity) { "parity-required" } else { "control-only" }
    $statusRows.Add("$($route.Path)`tGET=$($get.Status)`tHEAD=$($head.Status)`texpected-GET=$($route.ExpectedStatus)`t$headCriterion")
    $bodyRows.Add("$($route.Path)`tHEAD-bytes=$($head.BodyLength)")

    if ($get.Status -ne $route.ExpectedStatus) {
        $failures.Add("GET $($route.Path): expected $($route.ExpectedStatus), got $($get.Status)")
    }
    if ($route.AssertHeadParity -and $head.Status -ne $route.ExpectedStatus) {
        $failures.Add("HEAD $($route.Path): expected $($route.ExpectedStatus), got $($head.Status)")
    }
    if ($head.BodyLength -ne 0) {
        $failures.Add("HEAD $($route.Path): expected an empty body, got $($head.BodyLength) bytes")
    }

    foreach ($headerName in $selectedHeaders) {
        $getValue = Get-HeaderValue $get.Headers $headerName
        $headValue = Get-HeaderValue $head.Headers $headerName
        if ($getValue -ne $headValue) {
            $headerRows.Add("$($route.Path)`t$headerName`tGET=$getValue`tHEAD=$headValue")
        }
    }
}

$plainBodyPath = [IO.Path]::Combine($evidencePath, "plain.get.body.bin")
$plainHtml = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($plainBodyPath))
[IO.File]::WriteAllText([IO.Path]::Combine($evidencePath, "plain.html"), $plainHtml, [Text.UTF8Encoding]::new($false))
$renderModeMatch = [regex]::Match($plainHtml, '<h2 id="render-proof-title">([^<]+)</h2>')
$observedRenderMode = if ($renderModeMatch.Success) { $renderModeMatch.Groups[1].Value } else { "<missing>" }
Write-Artifact "render-mode.txt" "expected=$ExpectedRenderMode`nobserved=$observedRenderMode`n"
if ($ExpectedRenderMode -and $observedRenderMode -ne $ExpectedRenderMode) {
    $failures.Add("Render mode: expected $ExpectedRenderMode, observed $observedRenderMode")
}

$teapotHeaders = [IO.File]::ReadAllText([IO.Path]::Combine($evidencePath, "teapot.head.headers.txt"))
if ((Get-HeaderValue $teapotHeaders "X-Test") -ne "hello") {
    $failures.Add("HEAD /teapot: expected X-Test: hello")
}

$slowTeapotGetHeaders = [IO.File]::ReadAllText([IO.Path]::Combine($evidencePath, "slow-teapot.get.headers.txt"))
$slowTeapotHeadHeaders = [IO.File]::ReadAllText([IO.Path]::Combine($evidencePath, "slow-teapot.head.headers.txt"))
$lateMetadata = @(
    "GET-status=$((Get-Content ([IO.Path]::Combine($evidencePath, 'slow-teapot.get.timed.txt')) | Select-Object -First 1) -replace 'status=', '')",
    "GET-X-Test=$(Get-HeaderValue $slowTeapotGetHeaders 'X-Test')",
    "HEAD-status=$((Get-Content ([IO.Path]::Combine($evidencePath, 'slow-teapot.head.timed.txt')) | Select-Object -First 1) -replace 'status=', '')",
    "HEAD-X-Test=$(Get-HeaderValue $slowTeapotHeadHeaders 'X-Test')"
) -join "`n"
Write-Artifact "late-metadata.txt" ($lateMetadata + "`n")

Write-Artifact "status-comparison.txt" (($statusRows -join "`n") + "`n")
Write-Artifact "head-body-sizes.txt" (($bodyRows -join "`n") + "`n")
$headerSummary = if ($headerRows.Count -eq 0) { "No selected header differences.`n" } else { ($headerRows -join "`n") + "`n" }
Write-Artifact "header-differences.txt" $headerSummary

$gitSha = (& git rev-parse HEAD 2>$null) -join ""
$gitBranch = (& git branch --show-current 2>$null) -join ""
$gitStatus = (& git status --short 2>$null) -join "`n"
$gitDirty = if ($gitStatus) { "true" } else { "false" }
$invocationLine = if ($MyInvocation.Line) { $MyInvocation.Line.Trim() } else { $MyInvocation.MyCommand.Path }
$metadata = @(
    "capturedUtc=$([DateTime]::UtcNow.ToString('o'))",
    "baseUrl=$BaseUrl",
    "expectedRenderMode=$ExpectedRenderMode",
    "observedRenderMode=$observedRenderMode",
    "gitBranch=$gitBranch",
    "gitSha=$gitSha",
    "gitDirty=$gitDirty",
    "command=$invocationLine"
) -join "`n"
Write-Artifact "run-metadata.txt" ($metadata + "`n")
Write-Artifact "git-status.txt" ($gitStatus + "`n")
$sourceFiles = @(
    (Join-Path $PSScriptRoot "..\HeadValidation.csproj"),
    (Join-Path $PSScriptRoot "..\Program.cs"),
    (Join-Path $PSScriptRoot "..\Components\Pages\Slow.razor"),
    (Join-Path $PSScriptRoot "..\Components\Pages\SlowTeapot.razor"),
    $MyInvocation.MyCommand.Path
)
$sourceHashes = $sourceFiles | ForEach-Object {
    $resolvedPath = [IO.Path]::GetFullPath($_)
    $hash = (Get-FileHash $resolvedPath -Algorithm SHA256).Hash
    "$hash`t$resolvedPath"
}
Write-Artifact "source-hashes.txt" (($sourceHashes -join "`n") + "`n")
(& dotnet --info) | Out-File ([IO.Path]::Combine($evidencePath, "dotnet-info.txt")) -Encoding utf8

$exitCode = if ($failures.Count -eq 0) { 0 } else { 1 }
$result = @("exitCode=$exitCode") + $failures
Write-Artifact "result.txt" (($result -join "`n") + "`n")

Get-Content ([IO.Path]::Combine($evidencePath, "status-comparison.txt"))
Get-Content ([IO.Path]::Combine($evidencePath, "header-differences.txt"))
Get-Content ([IO.Path]::Combine($evidencePath, "result.txt"))
exit $exitCode