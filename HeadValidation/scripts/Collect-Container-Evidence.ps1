Param(
    [string]$BaseUrl = "http://localhost:5181",
    [string]$DockerExe = "C:\Users\SuryaElayaperumal\AppData\Local\Programs\Rancher Desktop\resources\resources\win32\bin\docker.exe",
    [string]$ContainerName = "headvalidation_interactive_manual"
)

$ts = Get-Date -Format yyyyMMdd-HHmmss
$dir = Join-Path (Get-Location) ("artifacts\container-run-$ts")
New-Item -ItemType Directory -Force -Path $dir | Out-Null

$routes = @('/plain','/item/42','/slow','/secure','/teapot','/missing-route','/logo.png')
foreach ($r in $routes) {
    $safe = ($r -replace '/','_').TrimStart('_')
    & curl.exe -sS -I "$BaseUrl$r" | Set-Content (Join-Path $dir ("$safe.head.headers.txt"))
    & curl.exe -sS -o NUL -D - "$BaseUrl$r" | Set-Content (Join-Path $dir ("$safe.get.headers.txt"))
}

Add-Type -AssemblyName System.Net.Http
$client = [System.Net.Http.HttpClient]::new()
$client.BaseAddress = [Uri]$BaseUrl
$before = [long]$client.GetStringAsync('/hits').GetAwaiter().GetResult()
$req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, '/plain')
$client.SendAsync($req).GetAwaiter().GetResult() | Out-Null
$after = [long]$client.GetStringAsync('/hits').GetAwaiter().GetResult()
@("before=$before","after=$after") | Set-Content (Join-Path $dir "hits.txt")

$sw = [diagnostics.stopwatch]::StartNew()
$req2 = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, '/slow')
$client.SendAsync($req2).GetAwaiter().GetResult() | Out-Null
$sw.Stop()
$head = $sw.Elapsed.TotalSeconds
$sw2 = [diagnostics.stopwatch]::StartNew()
$g = $client.GetAsync('/slow').GetAwaiter().GetResult()
$sw2.Stop()
$get = $sw2.Elapsed.TotalSeconds
@("HEAD=$head","GET=$get") | Set-Content (Join-Path $dir "slow.timings.txt")

& $DockerExe logs $ContainerName --since 1m | Set-Content (Join-Path $dir "container.logs.txt")
& $DockerExe inspect headvalidation:latest | Set-Content (Join-Path $dir "image.inspect.json")

Write-Host "Created $dir"
Get-ChildItem -Path $dir | Select-Object Name,Length | Format-Table -AutoSize
