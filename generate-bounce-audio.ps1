$ErrorActionPreference = 'Stop'
# Original, tiny PCM effects. Run only when intentionally changing the sound assets.
$outputDir = Join-Path $PSScriptRoot 'game/assets/audio'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
foreach ($kind in @('pop', 'stone', 'spring')) {
    $sampleRate = 22050
    $duration = if ($kind -eq 'spring') { 0.20 } else { 0.12 }
    $count = [int]($sampleRate * $duration)
    $stream = [IO.File]::Create((Join-Path $outputDir "$kind.wav"))
    $writer = [IO.BinaryWriter]::new($stream)
    try {
        $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
        $writer.Write([int](36 + $count * 2))
        $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
        $writer.Write([int]16); $writer.Write([int16]1); $writer.Write([int16]1)
        $writer.Write([int]$sampleRate); $writer.Write([int]($sampleRate * 2))
        $writer.Write([int16]2); $writer.Write([int16]16)
        $writer.Write([Text.Encoding]::ASCII.GetBytes('data')); $writer.Write([int]($count * 2))
        $phase = 0.0
        $noise = 0.0
        $random = [Random]::new(42)
        for ($i = 0; $i -lt $count; $i++) {
            $t = $i / [double]$sampleRate
            $frequency = if ($kind -eq 'spring') { 250 + 700 * [Math]::Exp(-$t * 13) + 35 * [Math]::Sin($t * 80) } else { 190 + 480 * [Math]::Exp(-$t * 45) }
            $phase += 2 * [Math]::PI * $frequency / $sampleRate
            $envelope = [Math]::Min(1, $t / 0.004) * [Math]::Exp(-$t * 30) * [Math]::Min(1, ($duration - $t) / 0.015)
            $tone = [Math]::Sin($phase) + 0.12 * [Math]::Sin($phase * 2)
            if ($kind -eq 'stone') {
                $noise = $noise * 0.6 + ($random.NextDouble() * 2 - 1) * 0.4
                $tone = $tone * 0.35 + $noise * 1.6
            }
            $writer.Write([int16]($tone * $envelope * 10000))
        }
    } finally { $writer.Dispose(); $stream.Dispose() }
}
