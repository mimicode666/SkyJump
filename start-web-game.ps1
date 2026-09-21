param([switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$siteUrl = 'http://127.0.0.1:4174/'
function Test-PlayerTwo {
    try {
        $page = Invoke-WebRequest -Uri $siteUrl -UseBasicParsing -TimeoutSec 2
        if ($page.Headers['X-Player-Two'] -ne 'godot-web') { throw 'Port 4174 is used by another application.' }
        return $true
    } catch [System.Net.WebException] { return $false }
}
try {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'build/web/index.html'))) { throw 'Web build is missing. Export the Web preset in Godot first (see game/WEB.md).' }
    if (-not (Test-PlayerTwo)) {
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
            if (Test-PlayerTwo) { $ready = $true; break }
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

