param([switch]$Editor)
$ErrorActionPreference = 'Stop'
$engine = Join-Path $PSScriptRoot '.tools\godot\Godot_v4.6-stable_win64.exe'
$project = Join-Path $PSScriptRoot 'game'
if (-not (Test-Path -LiteralPath $engine)) { throw 'Godot is missing from .tools/godot. See game/README.md.' }
$logDir = Join-Path $PSScriptRoot '.local'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $project '.godot\imported'))) {
    & $engine --headless --path $project --editor --import
    if ($LASTEXITCODE -ne 0) { throw 'Godot asset import failed.' }
}
$arguments = '--path "' + $project + '" --log-file "' + (Join-Path $logDir 'game.log') + '"'
if ($Editor) { $arguments += ' --editor' }
$gameProcess = Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $project -PassThru
Write-Output ('PLAYER TWO process: ' + $gameProcess.Id)
