$ErrorActionPreference = 'Stop'
$taskProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$taskGameRoot = 'D:\Games\Assetto Corsa\apps\lua\realvisor'
$taskModules = @('rain_environment.lua', 'rain_physics_units.lua', 'rain_birth_model.lua', 'rain_birth_gpu.lua')
$taskRecordPath = Join-Path $taskProjectRoot 'docs/diagnostics/2026-10-14/s75/installed_modules.json'
$taskPrevious = @{}
if (Test-Path -LiteralPath $taskRecordPath) {
    $taskPrevious = Get-Content -LiteralPath $taskRecordPath -Raw | ConvertFrom-Json -AsHashtable
}

# Inspect all targets first. Match existing links or our last installed copy;
# unrelated/user-edited game files are never replaced. No admin-only link creation.
$taskTargets = foreach ($taskModule in $taskModules) {
    $taskSource = [System.IO.Path]::GetFullPath((Join-Path $taskProjectRoot $taskModule))
    if (-not $taskSource.StartsWith($taskProjectRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unexpected module source: $taskSource"
    }
    if (-not (Test-Path -LiteralPath $taskSource -PathType Leaf)) { throw "Missing source: $taskSource" }
    $taskTarget = Join-Path $taskGameRoot $taskModule
    if (Test-Path -LiteralPath $taskTarget) {
        $taskItem = Get-Item -LiteralPath $taskTarget
        if ($taskItem.LinkType -eq 'SymbolicLink') {
            if ($taskItem.Target.Count -ne 1 -or [System.IO.Path]::GetFullPath($taskItem.Target[0]) -ne $taskSource) {
                throw "Existing unrelated module link requires review: $taskTarget"
            }
        } elseif ($taskItem.LinkType) {
            throw "Unsupported installed module link: $taskTarget"
        } else {
            $taskActualHash = (Get-FileHash -LiteralPath $taskTarget -Algorithm SHA256).Hash
            $taskDesiredHash = (Get-FileHash -LiteralPath $taskSource -Algorithm SHA256).Hash
            if ($taskActualHash -ne $taskDesiredHash -and $taskActualHash -ne $taskPrevious[$taskModule]) {
                throw "Existing unrelated or modified module requires review: $taskTarget"
            }
        }
    }
    [PSCustomObject]@{ Source = $taskSource; Target = $taskTarget; Module = $taskModule }
}
$taskInstalled = @{}
foreach ($taskTargetSpec in $taskTargets) {
    $taskSourceHash = (Get-FileHash -LiteralPath $taskTargetSpec.Source -Algorithm SHA256).Hash
    $taskExisting = Get-Item -LiteralPath $taskTargetSpec.Target -ErrorAction SilentlyContinue
    if (-not $taskExisting -or (-not $taskExisting.LinkType -and
        (Get-FileHash -LiteralPath $taskTargetSpec.Target -Algorithm SHA256).Hash -ne $taskSourceHash)) {
        Copy-Item -LiteralPath $taskTargetSpec.Source -Destination $taskTargetSpec.Target
    }
    $taskTargetHash = (Get-FileHash -LiteralPath $taskTargetSpec.Target -Algorithm SHA256).Hash
    if ($taskSourceHash -ne $taskTargetHash) { throw "Installed hash mismatch: $($taskTargetSpec.Target)" }
    $taskInstalled[$taskTargetSpec.Module] = $taskTargetHash
    Write-Output "$($taskTargetSpec.Target) matches $($taskTargetSpec.Source) SHA256=$taskTargetHash"
}
$taskInstalled | ConvertTo-Json | Set-Content -LiteralPath $taskRecordPath -Encoding utf8
