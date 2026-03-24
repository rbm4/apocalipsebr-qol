<#
.SYNOPSIS
    Compiles patched ServerGUI.java and deploys the .class to Project Zomboid.

.DESCRIPTION
    S1 Optimization: Skip texture pack loading on server GUI to save ~50-200+ MB RAM.

    This script:
    1. Locates or downloads a JDK 25+ compiler (javac)
    2. Backs up the original ServerGUI.class from projectzomboid.jar
    3. Compiles the patched source against projectzomboid.jar
    4. Deploys the resulting .class file to the PZ game directory
       (classpath override: loose .class files in game root take precedence over JAR)

.PARAMETER PZDir
    Path to the Project Zomboid installation directory.
    Default: Z:\SteamLibrary\steamapps\common\ProjectZomboid

.PARAMETER DryRun
    If set, shows what would be done without actually deploying.

.PARAMETER Revert
    If set, removes the deployed .class override (restoring original JAR behavior).

.NOTES
    PZ uses Azul Zulu JDK 25.0.1. The bundled JRE has no javac, so we need a full JDK.
    The script will auto-download Azul Zulu JDK 25 if no suitable compiler is found.

    The patch is controlled at runtime by a system property:
      -Dpz.server.gui.textures=true   → load all texture packs (original behavior)
      (default)                        → skip texture packs, save ~50-200+ MB RAM
#>
param(
    [string]$PZDir = "Z:\SteamLibrary\steamapps\common\ProjectZomboid",
    [string]$ToolsDir = $PSScriptRoot,
    [switch]$DryRun,
    [switch]$Revert
)

$ErrorActionPreference = "Stop"

# --- Configuration ---
$PatchName     = "S1: Skip Texture Packs on Server"
$SourceFile    = Join-Path $ToolsDir "zombie\network\ServerGUI.java"
$GameJar       = Join-Path $PZDir "projectzomboid.jar"
$DeployDir     = Join-Path $PZDir "zombie\network"
$DeployClass   = Join-Path $DeployDir "ServerGUI.class"
$BackupDir     = Join-Path $ToolsDir "backups"
$BackupClass   = Join-Path $BackupDir "ServerGUI.class.original"
$LocalJdkDir   = Join-Path $ToolsDir "jdk"
$OutputDir     = Join-Path $ToolsDir "out\classes"
$RequiredMajor = 25

# Azul Zulu JDK 25 download (Windows x64 zip)
$ZuluApiUrl    = "https://api.azul.com/metadata/v1/zulu/packages/?java_version=$RequiredMajor&os=windows&arch=x64&archive_type=zip&java_package_type=jdk&latest=true"

# --- Functions ---
function Get-JavacVersion {
    param([string]$JavacPath)
    try {
        $output = & $JavacPath -version 2>&1 | Out-String
        if ($output -match "javac\s+(\d+)") {
            return [int]$Matches[1]
        }
    } catch {}
    return 0
}

function Find-Javac {
    Write-Host "[*] Searching for javac >= $RequiredMajor..." -ForegroundColor Cyan

    # 1. Check local JDK folder (from previous download)
    $localJavac = Join-Path $LocalJdkDir "bin\javac.exe"
    if (Test-Path $localJavac) {
        $ver = Get-JavacVersion $localJavac
        if ($ver -ge $RequiredMajor) {
            Write-Host "    Found local JDK: javac $ver" -ForegroundColor Green
            return $localJavac
        }
    }

    # 2. Check PATH
    $pathJavac = Get-Command javac -ErrorAction SilentlyContinue
    if ($pathJavac) {
        $ver = Get-JavacVersion $pathJavac.Source
        if ($ver -ge $RequiredMajor) {
            Write-Host "    Found in PATH: javac $ver at $($pathJavac.Source)" -ForegroundColor Green
            return $pathJavac.Source
        } else {
            Write-Host "    PATH javac is version $ver (need >= $RequiredMajor)" -ForegroundColor Yellow
        }
    }

    # 3. Check common install locations
    $searchPaths = @(
        "C:\Program Files\Zulu\zulu-$RequiredMajor*\bin\javac.exe",
        "C:\Program Files\Eclipse Adoptium\jdk-$RequiredMajor*\bin\javac.exe",
        "C:\Program Files\Java\jdk-$RequiredMajor*\bin\javac.exe",
        "C:\Program Files\Microsoft\jdk-$RequiredMajor*\bin\javac.exe"
    )
    foreach ($pattern in $searchPaths) {
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $ver = Get-JavacVersion $found.FullName
            if ($ver -ge $RequiredMajor) {
                Write-Host "    Found installed: javac $ver at $($found.FullName)" -ForegroundColor Green
                return $found.FullName
            }
        }
    }

    return $null
}

function Install-Jdk {
    Write-Host "[*] Downloading Azul Zulu JDK $RequiredMajor..." -ForegroundColor Cyan

    try {
        $response = Invoke-RestMethod -Uri $ZuluApiUrl -TimeoutSec 30
        if ($response -is [array]) { $pkg = $response[0] } else { $pkg = $response }
        $downloadUrl = $pkg.download_url
    } catch {
        Write-Host "    Failed to query Azul API: $_" -ForegroundColor Red
        Write-Host "    Please manually install JDK 25+ and re-run this script." -ForegroundColor Yellow
        Write-Host "    Download from: https://www.azul.com/downloads/?version=java-25-lts&package=jdk#zulu" -ForegroundColor Yellow
        exit 1
    }

    if (-not $downloadUrl) {
        Write-Host "    Could not find download URL from Azul API." -ForegroundColor Red
        exit 1
    }

    Write-Host "    URL: $downloadUrl" -ForegroundColor Gray
    $zipPath = Join-Path $ToolsDir "jdk-download.zip"

    Write-Host "    Downloading..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
    Write-Host "    Download complete: $([math]::Round((Get-Item $zipPath).Length / 1MB, 1)) MB" -ForegroundColor Gray

    Write-Host "    Extracting..." -ForegroundColor Gray
    $extractDir = Join-Path $ToolsDir "jdk-extract"
    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    $innerDir = Get-ChildItem -Path $extractDir -Directory | Select-Object -First 1
    if (-not $innerDir) {
        Write-Host "    ERROR: Unexpected zip structure." -ForegroundColor Red
        exit 1
    }

    if (Test-Path $LocalJdkDir) { Remove-Item $LocalJdkDir -Recurse -Force }
    Move-Item $innerDir.FullName $LocalJdkDir

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue

    $javacPath = Join-Path $LocalJdkDir "bin\javac.exe"
    if (Test-Path $javacPath) {
        $ver = Get-JavacVersion $javacPath
        Write-Host "    Installed JDK $ver successfully." -ForegroundColor Green
        return $javacPath
    } else {
        Write-Host "    ERROR: javac.exe not found after extraction." -ForegroundColor Red
        exit 1
    }
}

function Backup-OriginalClass {
    if (Test-Path $BackupClass) {
        Write-Host "    Original backup already exists: $BackupClass" -ForegroundColor Gray
        return
    }

    Write-Host "[*] Extracting original ServerGUI.class from JAR..." -ForegroundColor Cyan
    if (-not (Test-Path $BackupDir)) {
        New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
    }

    $tempDir = Join-Path $ToolsDir "tmp-extract"
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

    Push-Location $tempDir
    try {
        & jar xf $GameJar "zombie/network/ServerGUI.class"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ERROR: Failed to extract class from JAR." -ForegroundColor Red
            exit 1
        }

        $extracted = Join-Path $tempDir "zombie\network\ServerGUI.class"
        if (-not (Test-Path $extracted)) {
            Write-Host "    ERROR: Expected class not found after extraction." -ForegroundColor Red
            exit 1
        }

        Copy-Item $extracted $BackupClass -Force
        Write-Host "    Backed up original: $BackupClass" -ForegroundColor Green
    } finally {
        Pop-Location
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- Main ---
Write-Host ""
Write-Host "=== $PatchName - Build & Deploy ===" -ForegroundColor White
Write-Host ""

# Handle revert
if ($Revert) {
    if (Test-Path $DeployClass) {
        Remove-Item $DeployClass -Force
        Write-Host "Removed class override: $DeployClass" -ForegroundColor Green

        # Clean up empty directory
        $remaining = Get-ChildItem $DeployDir -ErrorAction SilentlyContinue
        if (-not $remaining) {
            Remove-Item $DeployDir -Force -ErrorAction SilentlyContinue
        }

        Write-Host "Original ServerGUI from JAR will be used on next server start." -ForegroundColor Gray
    } else {
        Write-Host "No override found - already using original JAR class." -ForegroundColor Yellow
    }
    Write-Host ""
    exit 0
}

# Validate inputs
if (-not (Test-Path $SourceFile)) {
    Write-Host "ERROR: Source file not found: $SourceFile" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $GameJar)) {
    Write-Host "ERROR: Game JAR not found: $GameJar" -ForegroundColor Red
    Write-Host "       Set -PZDir to your ProjectZomboid installation" -ForegroundColor Yellow
    exit 1
}

# Step 1: Backup original class from JAR
Backup-OriginalClass

# Step 2: Find or install JDK
$javac = Find-Javac
if (-not $javac) {
    $javac = Install-Jdk
}

# Step 3: Compile
Write-Host ""
Write-Host "[*] Compiling patched ServerGUI.java..." -ForegroundColor Cyan
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

$javacArgs = @(
    "-cp", $GameJar,
    "-d", $OutputDir,
    "-encoding", "UTF-8",
    "-source", "25",
    "-target", "25",
    $SourceFile
)

Write-Host "    javac $($javacArgs -join ' ')" -ForegroundColor Gray
& $javac @javacArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Compilation failed (exit code $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}

$compiledClass = Join-Path $OutputDir "zombie\network\ServerGUI.class"
if (-not (Test-Path $compiledClass)) {
    Write-Host "ERROR: Expected output not found: $compiledClass" -ForegroundColor Red
    exit 1
}

Write-Host "    Compiled successfully." -ForegroundColor Green

# Step 4: Deploy
Write-Host ""
if ($DryRun) {
    Write-Host "[*] DRY RUN: Would deploy to $DeployClass" -ForegroundColor Yellow
} else {
    Write-Host "[*] Deploying..." -ForegroundColor Cyan

    # Create target directory in PZ root
    if (-not (Test-Path $DeployDir)) {
        New-Item -Path $DeployDir -ItemType Directory -Force | Out-Null
    }

    # Backup existing override if present
    if (Test-Path $DeployClass) {
        $backupPath = "$DeployClass.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $DeployClass $backupPath
        Write-Host "    Backed up previous override: $backupPath" -ForegroundColor Gray
    }

    # Deploy patched class
    Copy-Item $compiledClass $DeployClass -Force
    Write-Host "    Deployed: $DeployClass" -ForegroundColor Green
}

# Done
Write-Host ""
Write-Host "=== Done ===" -ForegroundColor White
Write-Host ""
Write-Host "Patch deployed: $PatchName" -ForegroundColor Green
Write-Host ""
Write-Host "How it works:" -ForegroundColor Gray
Write-Host "  PZ classpath is ['.', 'projectzomboid.jar'], so the loose .class" -ForegroundColor Gray
Write-Host "  at '$DeployDir' takes precedence over the one inside the JAR." -ForegroundColor Gray
Write-Host ""
Write-Host "  By default, texture packs are now SKIPPED when -gui is used," -ForegroundColor Gray
Write-Host "  saving ~50-200+ MB RAM. Headless servers are unaffected." -ForegroundColor Gray
Write-Host ""
Write-Host "  To re-enable full texture loading, add to JVM args:" -ForegroundColor Yellow
Write-Host "    -Dpz.server.gui.textures=true" -ForegroundColor Yellow
Write-Host ""
Write-Host "  To revert entirely:" -ForegroundColor Yellow
Write-Host "    .\build-deploy-s1-skip-textures.ps1 -Revert" -ForegroundColor Yellow
Write-Host "    (or delete: $DeployClass)" -ForegroundColor Yellow
Write-Host ""
