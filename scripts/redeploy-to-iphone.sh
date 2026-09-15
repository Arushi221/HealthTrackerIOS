#!/bin/zsh
# Rebuilds HealthTracker and reinstalls it on the paired iPhone. Free (non-paid)
# Apple Developer provisioning profiles expire after 7 days and iOS silently
# removes the app when that happens — this script exists to reinstall before
# that expiry so the app never actually disappears. Run on a schedule by the
# com.arushi.healthtracker.redeploy LaunchAgent (see scripts/README.md).

set -uo pipefail

PROJECT_DIR="/Users/arushi/HealthTrackerIOS"
DEVICE_ID="00008140-000D659A2130801C"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
LOG_DIR="$HOME/Library/Logs/HealthTrackerRedeploy"
LOG_FILE="$LOG_DIR/redeploy.log"

mkdir -p "$LOG_DIR"

log() {
    print -- "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >>"$LOG_FILE"
}

notify() {
    osascript -e "display notification \"$2\" with title \"$1\"" >/dev/null 2>&1
}

cd "$PROJECT_DIR" || { log "ERROR: project directory not found"; exit 1; }

log "Starting rebuild + reinstall"

# Skip the (slow, noisy) build entirely if the phone isn't reachable right
# now — xcodebuild would otherwise fail with a multi-hundred-line "no matching
# destination" dump for what is just an ordinary "not plugged in today" state.
if ! xcrun devicectl device info details --device "$DEVICE_ID" 2>/dev/null | grep -q "tunnelState: connected"; then
    log "SKIPPED: iPhone not reachable (not connected via USB or Wi-Fi)."
    notify "HealthTracker Redeploy" "Skipped — iPhone not reachable. Connect it via USB or Wi-Fi before the 7-day expiry."
    exit 0
fi

BUILD_OUTPUT=$(xcodebuild -scheme HealthTracker -destination "id=$DEVICE_ID" -allowProvisioningUpdates build 2>&1)
BUILD_STATUS=$?

if [ "$BUILD_STATUS" -ne 0 ]; then
    log "BUILD FAILED (exit $BUILD_STATUS):"
    print -- "$BUILD_OUTPUT" | tail -40 >>"$LOG_FILE"
    notify "HealthTracker Redeploy" "Build failed — check ~/Library/Logs/HealthTrackerRedeploy/redeploy.log"
    exit 1
fi

APP_PATH=$(find "$DERIVED_DATA" -maxdepth 6 -type d -name "HealthTracker.app" -path "*Debug-iphoneos*" -print -quit)
if [ -z "$APP_PATH" ]; then
    log "ERROR: built .app not found under $DERIVED_DATA"
    notify "HealthTracker Redeploy" "Build succeeded but the app bundle wasn't found."
    exit 1
fi

INSTALL_OUTPUT=$(xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" 2>&1)
INSTALL_STATUS=$?

if [ "$INSTALL_STATUS" -ne 0 ]; then
    log "INSTALL FAILED (exit $INSTALL_STATUS):"
    print -- "$INSTALL_OUTPUT" >>"$LOG_FILE"
    notify "HealthTracker Redeploy" "Couldn't reach your iPhone — connect it via USB or Wi-Fi. Will retry next cycle."
    exit 1
fi

log "Success: rebuilt and reinstalled."
notify "HealthTracker Redeploy" "Reinstalled successfully — good for another 7 days."
exit 0
