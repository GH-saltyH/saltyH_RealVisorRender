$ErrorActionPreference = 'Stop'
$projectPath = 'C:\source\LocalProjects\saltyH_RealVisorRender'
$appPath = 'D:\Games\Assetto Corsa\apps\lua\realvisor'
$sourcePath = Join-Path $projectPath 'rain_trails.lua'
$targetPath = Join-Path $appPath 'rain_trails.lua'
if (-not (Test-Path -LiteralPath $appPath -PathType Container)) { throw 'Game app folder missing' }
$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
if (Test-Path -LiteralPath $targetPath) {
    if ((Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash -ne $sourceHash) {
        throw 'A different installed rain_trails.lua exists; preserve it and inspect before replacing'
    }
} else {
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath
}
if ((Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash -ne $sourceHash) { throw 'Installed hash mismatch' }
Write-Output "Installed and verified: $targetPath"
