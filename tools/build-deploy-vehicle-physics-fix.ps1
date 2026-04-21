<#
.SYNOPSIS
    Compiles patched BaseVehicle.java and CarController.java and deploys the
    .class files to Project Zomboid (client-side classpath override).

.DESCRIPTION
    Vehicle Physics Fix: Prevents vehicles (especially towed trailers and semi
    trucks) from flying into the air due to:

    1. getFudgedMass() instantly dividing mass by 3.7 for towed vehicles every
       frame — now smoothed via configurable lerp rate (default 200 kg/frame).
    2. 30x FPS multiplier on applyCentralForceToVehicle() amplifying even
       clamped forces — now with vertical (Y) force clamping.
    3. CarController.updateTrailer() unconditionally breaking and recreating
       towing constraints every frame — now skips if constraint already exists.
    4. No vertical velocity sanity check — now clamps upward velocity.

    This is a CLIENT-SIDE patch. Deploy to each game client.

    System properties for tuning (add to ProjectZomboid64.json vmArgs):
      -Dpz.vehicle.mass.lerp.rate=200      Max kg/frame mass change (default 200)
      -Dpz.vehicle.max.vertical.force=5000  Max Y-axis force applied (default 5000)
      -Dpz.vehicle.max.vertical.velocity=8  Max vertical velocity m/s (default 8)

.PARAMETER PZDir
    Path to the Project Zomboid installation directory.
    Default: Z:\SteamLibrary\steamapps\common\ProjectZomboid

.PARAMETER DryRun
    If set, shows what would be done without actually deploying.

.PARAMETER Revert
    If set, removes deployed .class overrides (restoring original JAR behavior).

.NOTES
    PZ uses Azul Zulu JDK 25. The bundled JRE has no javac, so we need a full JDK.
    The script will auto-download Azul Zulu JDK 25 if no suitable compiler is found.
#>
param(
    [string]$PZDir = "Z:\SteamLibrary\steamapps\common\ProjectZomboid",
    [string]$ToolsDir = $PSScriptRoot,
    [switch]$DryRun,
    [switch]$Revert
)

$ErrorActionPreference = "Stop"

# --- Configuration ---
$PatchName          = "Vehicle Physics Fix: Anti-Flying Vehicles"
$SourceBaseVehicle  = Join-Path $ToolsDir "zombie\vehicles\BaseVehicle.java"
$SourceCarController = Join-Path $ToolsDir "zombie\core\physics\CarController.java"
$GameJar            = Join-Path $PZDir "projectzomboid.jar"
$BackupDir          = Join-Path $ToolsDir "backups"
$LocalJdkDir        = Join-Path $ToolsDir "jdk"
$OutputDir          = Join-Path $ToolsDir "out\classes"
$RequiredMajor      = 25

# Deploy targets
$DeployTargets = @(
    @{
        Name        = "BaseVehicle"
        Package     = "zombie\vehicles"
        ClassPrefix = "BaseVehicle"
        BackupName  = "BaseVehicle.class.original"
        JarEntry    = "zombie/vehicles/BaseVehicle.class"
    },
    @{
        Name        = "CarController"
        Package     = "zombie\core\physics"
        ClassPrefix = "CarController"
        BackupName  = "CarController.class.original"
        JarEntry    = "zombie/core/physics/CarController.class"
    }
)

# Azul Zulu JDK 25 download (Windows x64 zip)
$ZuluApiUrl = "https://api.azul.com/metadata/v1/zulu/packages/?java_version=$RequiredMajor&os=windows&arch=x64&archive_type=zip&java_package_type=jdk&latest=true"

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
    param(
        [string]$JarEntry,
        [string]$BackupName
    )

    $backupFile = Join-Path $BackupDir $BackupName
    if (Test-Path $backupFile) {
        Write-Host "    Backup exists: $backupFile" -ForegroundColor Gray
        return
    }

    Write-Host "    Extracting original $BackupName from JAR..." -ForegroundColor Cyan
    if (-not (Test-Path $BackupDir)) {
        New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
    }

    $tempDir = Join-Path $ToolsDir "tmp-extract"
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

    Push-Location $tempDir
    try {
        & jar xf $GameJar $JarEntry
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ERROR: Failed to extract $JarEntry from JAR." -ForegroundColor Red
            exit 1
        }

        $extracted = Join-Path $tempDir ($JarEntry -replace '/', '\')
        if (-not (Test-Path $extracted)) {
            Write-Host "    ERROR: $JarEntry not found after extraction." -ForegroundColor Red
            exit 1
        }

        Copy-Item $extracted $backupFile -Force
        Write-Host "    Backed up: $backupFile" -ForegroundColor Green
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
    $reverted = $false
    foreach ($target in $DeployTargets) {
        $deployDir = Join-Path $PZDir $target.Package
        $classFiles = Get-ChildItem -Path $deployDir -Filter "$($target.ClassPrefix)*.class" -ErrorAction SilentlyContinue
        foreach ($f in $classFiles) {
            Remove-Item $f.FullName -Force
            Write-Host "Removed: $($f.FullName)" -ForegroundColor Green
            $reverted = $true
        }

        # Clean up empty directories
        $remaining = Get-ChildItem $deployDir -ErrorAction SilentlyContinue
        if (-not $remaining -and (Test-Path $deployDir)) {
            Remove-Item $deployDir -Force -ErrorAction SilentlyContinue
        }
    }

    if ($reverted) {
        Write-Host ""
        Write-Host "Original classes from JAR will be used on next game start." -ForegroundColor Gray
    } else {
        Write-Host "No overrides found - already using original JAR classes." -ForegroundColor Yellow
    }
    Write-Host ""
    exit 0
}

# Validate inputs
if (-not (Test-Path $SourceBaseVehicle)) {
    Write-Host "ERROR: Source not found: $SourceBaseVehicle" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $SourceCarController)) {
    Write-Host "ERROR: Source not found: $SourceCarController" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $GameJar)) {
    Write-Host "ERROR: Game JAR not found: $GameJar" -ForegroundColor Red
    Write-Host "       Set -PZDir to your ProjectZomboid installation" -ForegroundColor Yellow
    exit 1
}

# Step 1: Backup original classes from JAR
Write-Host "[1/4] Backing up original classes..." -ForegroundColor Cyan
foreach ($target in $DeployTargets) {
    Backup-OriginalClass -JarEntry $target.JarEntry -BackupName $target.BackupName
}

# Step 2: Find or install JDK
$javac = Find-Javac
if (-not $javac) {
    $javac = Install-Jdk
}

# Step 3: Compile both source files
Write-Host ""
Write-Host "[3/4] Compiling patched sources..." -ForegroundColor Cyan
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

$javacArgs = @(
    "-cp", $GameJar,
    "-d", $OutputDir,
    "-encoding", "UTF-8",
    "-source", "25",
    "-target", "25",
    $SourceBaseVehicle,
    $SourceCarController
)

Write-Host "    javac $($javacArgs -join ' ')" -ForegroundColor Gray
& $javac @javacArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Compilation failed (exit code $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}

# Verify outputs exist
foreach ($target in $DeployTargets) {
    $compiledClass = Join-Path $OutputDir ($target.Package + "\" + $target.ClassPrefix + ".class")
    if (-not (Test-Path $compiledClass)) {
        Write-Host "ERROR: Expected output not found: $compiledClass" -ForegroundColor Red
        exit 1
    }
}

Write-Host "    Compiled successfully." -ForegroundColor Green

# Step 4: Deploy
Write-Host ""
if ($DryRun) {
    Write-Host "[4/4] DRY RUN: Would deploy these files:" -ForegroundColor Yellow
    foreach ($target in $DeployTargets) {
        $compiledDir = Join-Path $OutputDir $target.Package
        Get-ChildItem -Path $compiledDir -Filter "$($target.ClassPrefix)*.class" | ForEach-Object {
            $deployPath = Join-Path (Join-Path $PZDir $target.Package) $_.Name
            Write-Host "    $deployPath" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "[4/4] Deploying..." -ForegroundColor Cyan
    $totalDeployed = 0

    foreach ($target in $DeployTargets) {
        $deployDir = Join-Path $PZDir $target.Package
        if (-not (Test-Path $deployDir)) {
            New-Item -Path $deployDir -ItemType Directory -Force | Out-Null
        }

        $compiledDir = Join-Path $OutputDir $target.Package
        Get-ChildItem -Path $compiledDir -Filter "$($target.ClassPrefix)*.class" | ForEach-Object {
            $destPath = Join-Path $deployDir $_.Name

            # Backup existing override
            if (Test-Path $destPath) {
                $backupPath = "$destPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item $destPath $backupPath
                Write-Host "    Backed up previous: $backupPath" -ForegroundColor Gray
            }

            Copy-Item $_.FullName $destPath -Force
            Write-Host "    Deployed: $destPath" -ForegroundColor Green
            $totalDeployed++
        }
    }

    Write-Host ""
    Write-Host "    Total: $totalDeployed class files deployed." -ForegroundColor Green
}

# Done
Write-Host ""
Write-Host "=== Done ===" -ForegroundColor White
Write-Host ""
Write-Host "Patch: $PatchName" -ForegroundColor Green
Write-Host ""
Write-Host "How it works:" -ForegroundColor Gray
Write-Host "  PZ classpath is ['.', 'projectzomboid.jar'], so loose .class files" -ForegroundColor Gray
Write-Host "  take precedence over those inside the JAR." -ForegroundColor Gray
Write-Host ""
Write-Host "What was patched:" -ForegroundColor Gray
Write-Host "  BaseVehicle.java:" -ForegroundColor Gray
Write-Host "    - getFudgedMass(): smooth mass lerp instead of instant /3.7 jump" -ForegroundColor Gray
Write-Host "    - applyAccumulatedImpulsesFromHitObjectsToPhysics(): Y-force clamp" -ForegroundColor Gray
Write-Host "    - applyAllImpulsesFromProneCharacters(): Y-force clamp" -ForegroundColor Gray
Write-Host "    - Post-collision vertical velocity sanity check" -ForegroundColor Gray
Write-Host "  CarController.java:" -ForegroundColor Gray
Write-Host "    - updateTrailer(): skip constraint recreation if already exists" -ForegroundColor Gray
Write-Host "    - update(): same guard for towing constraint" -ForegroundColor Gray
Write-Host ""
Write-Host "Tuning (add to ProjectZomboid64.json vmArgs):" -ForegroundColor Gray
Write-Host "  -Dpz.vehicle.mass.lerp.rate=200        (kg/frame, default 200)" -ForegroundColor Gray
Write-Host "  -Dpz.vehicle.max.vertical.force=5000   (Newtons, default 5000)" -ForegroundColor Gray
Write-Host "  -Dpz.vehicle.max.vertical.velocity=8   (m/s, default 8)" -ForegroundColor Gray
Write-Host ""
Write-Host "To revert:" -ForegroundColor Yellow
Write-Host "  .\build-deploy-vehicle-physics-fix.ps1 -Revert" -ForegroundColor Yellow
Write-Host ""
