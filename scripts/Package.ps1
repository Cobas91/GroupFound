<#
.SYNOPSIS
    Packt das GroupFound-Addon als ZIP fuer den Upload auf CurseForge.

.DESCRIPTION
    Liest die Version aus GroupFound.toc (## Version: x.y.z), kopiert den
    Addon-Quellordner in ein sauberes Staging-Verzeichnis und erstellt daraus
    dist\GroupFound-<version>.zip mit der korrekten Ordnerstruktur
    (GroupFound\GroupFound.toc, GroupFound\Core.lua, ...) direkt im ZIP-Root.

.PARAMETER Version
    Optional. Ueberschreibt die aus der .toc gelesene Version.

.PARAMETER Deploy
    Optional. Kopiert den Addon-Ordner zusaetzlich in den WoW AddOns-Ordner.

.PARAMETER WowAddonsPath
    Zielpfad fuer -Deploy. Standard: die _classic_era_ AddOns-Installation.

.EXAMPLE
    .\scripts\Package.ps1

.EXAMPLE
    .\scripts\Package.ps1 -Deploy
#>

param(
    [string]$Version,
    [switch]$Deploy,
    [string]$WowAddonsPath = "D:\Games\World of Warcraft\_classic_era_\Interface\AddOns"
)

$ErrorActionPreference = "Stop"

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$AddonName  = "GroupFound"
$SourceDir  = Join-Path $RepoRoot $AddonName
$DistDir    = Join-Path $RepoRoot "dist"
$TocFile    = Join-Path $SourceDir "$AddonName.toc"

if (-not (Test-Path $SourceDir)) {
    throw "Addon-Quellordner nicht gefunden: $SourceDir"
}
if (-not (Test-Path $TocFile)) {
    throw ".toc-Datei nicht gefunden: $TocFile"
}

if (-not $Version) {
    $tocContent = Get-Content $TocFile -Raw
    if ($tocContent -match '(?m)^##\s*Version:\s*(.+)$') {
        $Version = $Matches[1].Trim()
    } else {
        throw "Konnte Version nicht aus $TocFile lesen. Bitte -Version angeben."
    }
}

Write-Host "Packe $AddonName Version $Version ..." -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

# Sauberes Staging-Verzeichnis aufbauen, damit keine Dev-Dateien (.git, .vscode, ...) ins ZIP wandern.
$StagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("TradeGuardPackage_" + [System.Guid]::NewGuid().ToString("N"))
$StagingAddonDir = Join-Path $StagingRoot $AddonName
New-Item -ItemType Directory -Force -Path $StagingAddonDir | Out-Null

$ExcludeNames = @(".git", ".vscode", ".gitignore", ".DS_Store")

Get-ChildItem -Path $SourceDir -Recurse -Force | Where-Object {
    $item = $_
    -not ($ExcludeNames | Where-Object { $item.Name -eq $_ })
} | ForEach-Object {
    $relativePath = $_.FullName.Substring($SourceDir.Length).TrimStart('\')
    $destPath = Join-Path $StagingAddonDir $relativePath
    if ($_.PSIsContainer) {
        New-Item -ItemType Directory -Force -Path $destPath | Out-Null
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $destPath) | Out-Null
        Copy-Item -Path $_.FullName -Destination $destPath -Force
    }
}

$ZipPath = Join-Path $DistDir "$AddonName-$Version.zip"
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

Compress-Archive -Path $StagingAddonDir -DestinationPath $ZipPath -CompressionLevel Optimal

Remove-Item -Recurse -Force $StagingRoot

Write-Host "Fertig: $ZipPath" -ForegroundColor Green
Write-Host "Dieses ZIP kann direkt auf CurseForge hochgeladen werden (enthaelt $AddonName\$AddonName.toc im Root)."

if ($Deploy) {
    $DeployTarget = Join-Path $WowAddonsPath $AddonName
    Write-Host "Deploye nach $DeployTarget ..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $DeployTarget | Out-Null
    Get-ChildItem -Path $DeployTarget -Recurse -Force | Remove-Item -Recurse -Force
    Copy-Item -Path (Join-Path $SourceDir '*') -Destination $DeployTarget -Recurse -Force
    Write-Host "Deploy abgeschlossen." -ForegroundColor Green
}
