param([switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$siteUrl = 'http://127.0.0.1:4174/'
function Test-SkyJump {
    try {
        $page = Invoke-WebRequest -Uri $siteUrl -UseBasicParsing -TimeoutSec 2
        if (-not $page.Headers['X-SkyJump']) { throw 'Port 4174 is used by another application.' }
        return $true
    } catch [System.Net.WebException] { return $false }
}
try {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'build/web/index.html'))) { throw 'This folder contains source code. Download the ready game: https://github.com/mimicode666/SkyJump/releases/latest (no Godot needed).' }
    if (-not (Test-SkyJump)) {
        $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
        $nodePath = if ($nodeCommand) { $nodeCommand.Source } else { Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' }
        if (-not (Test-Path -LiteralPath $nodePath)) { throw 'Node.js was not found. Install Node.js, then run this file again.' }
        $logDir = Join-Path $PSScriptRoot '.local'
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
        $serverFile = Join-Path $PSScriptRoot 'server-game.mjs'
        $process = Start-Process -FilePath $nodePath -ArgumentList ('"' + $serverFile + '"') -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logDir 'web-game.log') -RedirectStandardError (Join-Path $logDir 'web-game-error.log') -PassThru
        $ready = $false
        for ($attempt = 0; $attempt -lt 20; $attempt++) {
            Start-Sleep -Milliseconds 250
            if (Test-SkyJump) { $ready = $true; break }
            if ($process.HasExited) { break }
        }
        if (-not $ready) { throw "Server failed to start. See $logDir\web-game-error.log" }
        Set-Content -LiteralPath (Join-Path $logDir 'web-game.pid') -Value $process.Id
    }
    Write-Host "SkyJump is running: $siteUrl"
    if (-not $NoBrowser) { Start-Process $siteUrl }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

