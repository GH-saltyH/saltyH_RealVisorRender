$ErrorActionPreference = 'Stop'
$s66Source = 'C:\source\LocalProjects\saltyH_RealVisorRender\native_glass_occlusion.lua'
$s66Destination = 'D:\Games\Assetto Corsa\apps\lua\realvisor\native_glass_occlusion.lua'
$s66ExpectedFolder = 'D:\Games\Assetto Corsa\apps\lua\realvisor'
if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($s66Destination)) -ne $s66ExpectedFolder) {
    throw 'Unexpected destination'
}
$s66SourceHash = (Get-FileHash -LiteralPath $s66Source -Algorithm SHA256).Hash
$s66InstalledItem = Get-Item -LiteralPath $s66Destination -Force -ErrorAction SilentlyContinue
if ($s66InstalledItem -and $s66InstalledItem.LinkType -eq 'SymbolicLink' -and
    $s66InstalledItem.Target -eq 'C:\source\LocalProjects\saltyH_RealVisorRender\native_glass_occlusionlua') {
    if ([IO.File]::Exists($s66InstalledItem.Target)) { throw 'Unexpected live typo target; no modification performed' }
    # Remove this verified dangling link only; its target does not exist.
    Remove-Item -LiteralPath $s66Destination -Force
    Write-Output 'Removed dangling module link with missing dot before lua'
}
if (Test-Path -LiteralPath $s66Destination) {
    if ((Get-FileHash -LiteralPath $s66Destination -Algorithm SHA256).Hash -ne $s66SourceHash) {
        throw 'Existing installed module differs; no overwrite performed'
    }
    Write-Output 'Required native module is already current'
} else {
    try {
        New-Item -ItemType SymbolicLink -Path $s66Destination -Target $s66Source -ErrorAction Stop | Out-Null
        Write-Output 'Installed missing native module as a source link'
    } catch {
        if (Test-Path -LiteralPath $s66Destination) { throw }
        Copy-Item -LiteralPath $s66Source -Destination $s66Destination
        Write-Output 'Installed missing native module as a file (link creation unavailable)'
    }
}
if ((Get-FileHash -LiteralPath $s66Destination -Algorithm SHA256).Hash -ne $s66SourceHash) {
    throw 'Installed module hash verification failed'
}
Write-Output 'Native module SHA256 verified; no settings files modified'
