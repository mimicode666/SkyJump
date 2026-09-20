param([switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$siteUrl = 'http://127.0.0.1:4173/'
function Test-PlayerTwo {
    try {
        $page = Invoke-WebRequest -Uri $siteUrl -UseBasicParsing -TimeoutSec 2
        if ($page.Content -notmatch '<title>PLAYER TWO') { throw 'Port 4173 is used by another application.' }
        return $true
    } catch [System.Net.WebException] { return $false }
}
try {
    if (-not (Test-PlayerTwo)) {
        $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
        $nodePath = if ($nodeCommand) { $nodeCommand.Source } else { Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' }
        if (-not (Test-Path -LiteralPath $nodePath)) { throw 'Node.js was not found. Install Node.js, then run this file again.' }
        $logDir = Join-Path $PSScriptRoot '.local'
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
        $serverFile = Join-Path $PSScriptRoot 'server.mjs'
        $process = Start-Process -FilePath $nodePath -ArgumentList ('"' + $serverFile + '"') -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logDir 'server.log') -RedirectStandardError (Join-Path $logDir 'server-error.log') -PassThru
        $ready = $false
        for ($attempt = 0; $attempt -lt 20; $attempt++) {
            Start-Sleep -Milliseconds 250
            if (Test-PlayerTwo) { $ready = $true; break }
            if ($process.HasExited) { break }
        }
        if (-not $ready) { throw "Server failed to start. See $logDir\server-error.log" }
        Set-Content -LiteralPath (Join-Path $logDir 'server.pid') -Value $process.Id
    }
    Write-Host "PLAYER TWO is running: $siteUrl"
    if (-not $NoBrowser) { Start-Process $siteUrl }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
