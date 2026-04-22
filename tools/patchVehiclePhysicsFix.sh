#!/bin/bash
# filepath: patchVehiclePhysicsFix.sh
# Vehicle Physics Fix: Prevents vehicles (especially towed trailers and semi
# trucks) from flying into the air.
#
# Compiles patched BaseVehicle.java and CarController.java and deploys via
# classpath override. Server-side patch.
#
# What is patched:
#   BaseVehicle.java:
#     - getFudgedMass(): smooth mass lerp instead of instant /3.7 jump
#     - applyAccumulatedImpulsesFromHitObjectsToPhysics(): Y-force clamp
#     - applyAllImpulsesFromProneCharacters(): Y-force clamp
#     - Post-collision vertical velocity sanity check
#   CarController.java:
#     - updateTrailer(): skip constraint recreation if already exists
#     - update(): same guard for towing constraint
#
# Strategy: Classpath order in server config is:
#   "classpath": ["java/.", "java/projectzomboid.jar"]
# Loose .class files under /opt/pzserver/java/ are loaded BEFORE those in the JAR.
#
# System properties for tuning (add to server JSON vmArgs):
#   -Dpz.vehicle.mass.lerp.rate=200      Max kg/frame mass change (default 200)
#   -Dpz.vehicle.max.vertical.force=5000  Max Y-axis force applied (default 5000)
#   -Dpz.vehicle.max.vertical.velocity=8  Max vertical velocity m/s (default 8)
#
# Usage:
#   ./patchVehiclePhysicsFix.sh              # compile & deploy
#   ./patchVehiclePhysicsFix.sh --revert     # remove overrides
#   ./patchVehiclePhysicsFix.sh --dry-run    # show what would happen

set -e

# --- Configuration ---
PZ_DIR="/opt/pzserver"
JAR_FILE="$PZ_DIR/java/projectzomboid.jar"
CLASSPATH_DIR="$PZ_DIR/java"
JAVAC="/usr/lib/jvm/java-25-openjdk-amd64/bin/javac"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="/tmp/pzpatch_vehicle_physics"

# Source files (must be alongside this script in zombie/ subfolder)
SRC_BASE_VEHICLE="$SCRIPT_DIR/zombie/vehicles/BaseVehicle.java"
SRC_CAR_CONTROLLER="$SCRIPT_DIR/zombie/core/physics/CarController.java"

# Deploy locations
DEPLOY_BASE_VEHICLE="$CLASSPATH_DIR/zombie/vehicles"
DEPLOY_CAR_CONTROLLER="$CLASSPATH_DIR/zombie/core/physics"

REVERT=false
DRY_RUN=false

# --- Parse args ---
for arg in "$@"; do
    case "$arg" in
        --revert)  REVERT=true ;;
        --dry-run) DRY_RUN=true ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [--revert] [--dry-run]"
            exit 1
            ;;
    esac
done

echo ""
echo "=== Vehicle Physics Fix - Build & Deploy ==="
echo ""

# --- Revert ---
if [ "$REVERT" = true ]; then
    reverted=false

    for f in "$DEPLOY_BASE_VEHICLE"/BaseVehicle*.class; do
        [ -e "$f" ] || continue
        rm -f "$f"
        echo "Removed: $f"
        reverted=true
    done

    for f in "$DEPLOY_CAR_CONTROLLER"/CarController*.class; do
        [ -e "$f" ] || continue
        rm -f "$f"
        echo "Removed: $f"
        reverted=true
    done

    # Clean empty dirs
    [ -d "$DEPLOY_BASE_VEHICLE" ] && rmdir --ignore-fail-on-non-empty "$DEPLOY_BASE_VEHICLE" 2>/dev/null || true
    [ -d "$DEPLOY_CAR_CONTROLLER" ] && rmdir --ignore-fail-on-non-empty "$DEPLOY_CAR_CONTROLLER" 2>/dev/null || true

    if [ "$reverted" = true ]; then
        echo ""
        echo "Original classes from JAR will be used on next server start."
    else
        echo "No overrides found - already using original JAR classes."
    fi
    echo ""
    exit 0
fi

# --- Validate ---
if [ ! -f "$JAVAC" ]; then
    echo "ERROR: javac not found at $JAVAC"
    echo "Install: apt install openjdk-25-jdk-headless"
    exit 1
fi

if [ ! -f "$JAR_FILE" ]; then
    echo "ERROR: JAR not found at $JAR_FILE"
    echo "Set PZ_DIR at the top of this script to your server installation."
    exit 1
fi

if [ ! -f "$SRC_BASE_VEHICLE" ]; then
    echo "ERROR: Source not found: $SRC_BASE_VEHICLE"
    echo "Expected zombie/vehicles/BaseVehicle.java relative to this script."
    exit 1
fi

if [ ! -f "$SRC_CAR_CONTROLLER" ]; then
    echo "ERROR: Source not found: $SRC_CAR_CONTROLLER"
    echo "Expected zombie/core/physics/CarController.java relative to this script."
    exit 1
fi

# --- Compile ---
echo "[1/3] Compiling patched sources..."

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/build"

"$JAVAC" \
    -cp "$JAR_FILE" \
    -d "$WORK_DIR/build" \
    -encoding UTF-8 \
    -source 25 \
    -target 25 \
    "$SRC_BASE_VEHICLE" \
    "$SRC_CAR_CONTROLLER"

# Verify compilation output
if [ ! -f "$WORK_DIR/build/zombie/vehicles/BaseVehicle.class" ]; then
    echo "ERROR: BaseVehicle.class not found after compilation."
    exit 1
fi
if [ ! -f "$WORK_DIR/build/zombie/core/physics/CarController.class" ]; then
    echo "ERROR: CarController.class not found after compilation."
    exit 1
fi

echo "    Compiled successfully."

# --- Deploy ---
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "[2/3] DRY RUN: Would deploy these files:"
    for f in "$WORK_DIR/build/zombie/vehicles"/BaseVehicle*.class; do
        [ -e "$f" ] || continue
        echo "    $DEPLOY_BASE_VEHICLE/$(basename "$f")"
    done
    for f in "$WORK_DIR/build/zombie/core/physics"/CarController*.class; do
        [ -e "$f" ] || continue
        echo "    $DEPLOY_CAR_CONTROLLER/$(basename "$f")"
    done
else
    echo "[2/3] Deploying..."
    total=0

    mkdir -p "$DEPLOY_BASE_VEHICLE"
    for f in "$WORK_DIR/build/zombie/vehicles"/BaseVehicle*.class; do
        [ -e "$f" ] || continue
        dest="$DEPLOY_BASE_VEHICLE/$(basename "$f")"
        # Backup existing override
        if [ -f "$dest" ]; then
            backup="${dest}.bak.$(date +%Y%m%d-%H%M%S)"
            cp "$dest" "$backup"
            echo "    Backed up previous: $backup"
        fi
        cp "$f" "$dest"
        echo "    Deployed: $dest"
        total=$((total + 1))
    done

    mkdir -p "$DEPLOY_CAR_CONTROLLER"
    for f in "$WORK_DIR/build/zombie/core/physics"/CarController*.class; do
        [ -e "$f" ] || continue
        dest="$DEPLOY_CAR_CONTROLLER/$(basename "$f")"
        if [ -f "$dest" ]; then
            backup="${dest}.bak.$(date +%Y%m%d-%H%M%S)"
            cp "$dest" "$backup"
            echo "    Backed up previous: $backup"
        fi
        cp "$f" "$dest"
        echo "    Deployed: $dest"
        total=$((total + 1))
    done

    echo ""
    echo "    Total: $total class files deployed."
fi

# --- Cleanup ---
echo ""
echo "[3/3] Cleaning up..."
rm -rf "$WORK_DIR"
echo "    Done."

# --- Summary ---
echo ""
echo "=== Done ==="
echo ""
echo "Patch: Vehicle Physics Fix - Anti-Flying Vehicles"
echo ""
echo "What was patched:"
echo "  BaseVehicle.java:"
echo "    - getFudgedMass(): smooth mass lerp instead of instant /3.7 jump"
echo "    - applyAccumulatedImpulsesFromHitObjectsToPhysics(): Y-force clamp"
echo "    - applyAllImpulsesFromProneCharacters(): Y-force clamp"
echo "    - Post-collision vertical velocity sanity check"
echo "  CarController.java:"
echo "    - updateTrailer(): skip constraint recreation if already exists"
echo "    - update(): same guard for towing constraint"
echo ""
echo "Tuning (add to server JSON vmArgs):"
echo "  -Dpz.vehicle.mass.lerp.rate=200        (kg/frame, default 200)"
echo "  -Dpz.vehicle.max.vertical.force=5000   (Newtons, default 5000)"
echo "  -Dpz.vehicle.max.vertical.velocity=8   (m/s, default 8)"
echo ""
echo "To revert:"
echo "  ./patchVehiclePhysicsFix.sh --revert"
echo ""
