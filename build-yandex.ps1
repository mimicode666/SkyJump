$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$enginePath = Join-Path $projectRoot '.tools/godot/Godot_v4.6-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { throw 'Godot 4.6 was not found in .tools/godot.' }

# A fresh staging folder prevents old debug exports from entering the archive.
$stagingPath = Join-Path $projectRoot ('build/yandex-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $stagingPath -Force | Out-Null
& $enginePath --headless --path (Join-Path $projectRoot 'game') --export-release Web (Join-Path $stagingPath 'index.html')
if ($LASTEXITCODE -ne 0) { throw 'Godot Web export failed.' }

$files = @(Get-ChildItem -LiteralPath $stagingPath -File)
foreach ($file in $files) {
    if ($file.Name -notmatch '^index\.[a-z0-9.-]+$') { throw "Unexpected archive file: $($file.Name)" }
}
foreach ($requiredName in @('index.html', 'index.js', 'index.wasm', 'index.pck')) {
    if (-not (Test-Path -LiteralPath (Join-Path $stagingPath $requiredName))) { throw "Missing $requiredName" }
}
$uncompressedBytes = ($files | Measure-Object -Property Length -Sum).Sum
if ($uncompressedBytes -gt 100000000) { throw 'The uncompressed game exceeds the 100 MB platform limit.' }
$archivePath = Join-Path $projectRoot 'build/SkyJump-Yandex.zip'
Compress-Archive -LiteralPath $files.FullName -DestinationPath $archivePath -Force
Write-Output "Archive: $archivePath"
Write-Output ('Uncompressed: {0:N2} MB; files: {1}' -f ($uncompressedBytes / 1000000), $files.Count)
Write-Output 'Local artifact only. Nothing has been uploaded or published.'
