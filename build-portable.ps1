param(
    [string]$Godot = "$PSScriptRoot/.tools/godot/Godot_v4.6-stable_win64_console.exe",
    [string]$Go = "$PSScriptRoot/.tools/go-sdk/go/bin/go.exe",
    [switch]$SkipExport
)
$ErrorActionPreference = 'Stop'
$version = (Get-Content "$PSScriptRoot/package.json" -Raw | ConvertFrom-Json).version
if (-not (Test-Path -LiteralPath $Go)) { throw 'Build tool Go is missing. See game/README.md. Players do not need Go or Godot.' }
$Go = (Resolve-Path -LiteralPath $Go).Path
$work = Join-Path $PSScriptRoot ('build/portable-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$web = Join-Path $work 'web'
$release = Join-Path $PSScriptRoot "build/releases/v$version"
New-Item -ItemType Directory -Force $web, $release | Out-Null
if ($SkipExport) {
    Copy-Item "$PSScriptRoot/build/web/index.*" $web
} else {
    if (-not (Test-Path -LiteralPath $Godot)) { throw 'Install Godot 4.6 and its export templates; see game/README.md.' }
    & $Godot --headless --path "$PSScriptRoot/game" --export-release Web "$web/index.html"
    if ($LASTEXITCODE -ne 0) { throw 'Godot Web export failed.' }
}
foreach ($file in @('index.html','index.js','index.wasm','index.pck')) {
    if (-not (Test-Path -LiteralPath "$web/$file")) { throw "Incomplete export: $file" }
}
if ((Get-Content "$web/index.html" -Raw) -notmatch '"args":\[\]') { throw 'Only a normal release without QA arguments can be packaged.' }
$buildId = "v$version-" + (Get-FileHash "$web/index.pck" -Algorithm SHA256).Hash.Substring(0, 16).ToLowerInvariant()
$originalOS = $env:GOOS
$originalArch = $env:GOARCH
$originalCGO = $env:CGO_ENABLED
$originalCache = $env:GOCACHE
try {
    $env:CGO_ENABLED = '0'
    $env:GOARCH = 'amd64'
    $env:GOCACHE = Join-Path $PSScriptRoot '.local/go-cache'
    Push-Location "$PSScriptRoot/tools/launcher"
    try {
        foreach ($target in @('windows','linux')) {
            $folderName = "SkyJump-$version-$target-x64"
            $folder = Join-Path $work $folderName
            New-Item -ItemType Directory -Force "$folder/web" | Out-Null
            Copy-Item "$web/index.*" "$folder/web"
            Copy-Item "$PSScriptRoot/tools/launcher/README.txt" "$folder/README.txt"
            Copy-Item "$PSScriptRoot/THIRD_PARTY.md" "$folder/THIRD_PARTY.md"
            Copy-Item "$PSScriptRoot/game/THIRD_PARTY_ENGINE.txt" "$folder/THIRD_PARTY_ENGINE.txt"
            $env:GOOS = $target
            $binary = if ($target -eq 'windows') { 'SkyJump.exe' } else { 'SkyJump' }
            & $Go build -trimpath -ldflags "-s -w -X main.buildID=$buildId" -o "$folder/$binary" .
            if ($LASTEXITCODE -ne 0) { throw "Launcher build failed: $target" }
            if ($target -eq 'windows') {
                Compress-Archive -Path $folder -DestinationPath "$release/$folderName.zip" -Force
            } else {
                Copy-Item "$PSScriptRoot/tools/launcher/play-skyjump.sh" "$folder/play-skyjump.sh"
                & tar -czf "$release/$folderName.tar.gz" -C $work $folderName
                if ($LASTEXITCODE -ne 0) { throw 'Linux archive failed.' }
            }
        }
    } finally { Pop-Location }
    $hashes = Get-ChildItem $release -File | Where-Object Name -Match '\.(zip|tar\.gz)$' | ForEach-Object {
        (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.Name
    }
    $hashes | Set-Content "$release/SHA256SUMS.txt" -Encoding ascii
    Write-Output "Ready: $release"
    Get-ChildItem $release | Select-Object Name, Length
} finally {
    $env:GOOS = $originalOS
    $env:GOARCH = $originalArch
    $env:CGO_ENABLED = $originalCGO
    $env:GOCACHE = $originalCache
}
