# redeploy-to-iphone.sh

Free (non-paid) Apple Developer provisioning profiles expire after 7 days —
when that happens, iOS silently removes the app from the phone. This script
rebuilds and reinstalls HealthTracker on a paired iPhone so that never
happens, as long as it runs before the 7-day mark.

It's driven by a local LaunchAgent (not checked into this repo — it lives in
`~/Library/LaunchAgents` and is specific to the Mac it's set up on) that runs
it every 5 days, leaving a 2-day buffer before expiry.

## What it does

1. Checks whether the iPhone is currently reachable (USB or wireless
   debugging). If not, it skips the build entirely and sends a notification
   asking you to connect the phone — no point burning a build for a device
   that isn't there.
2. If reachable, runs `xcodebuild` for the device and installs the result via
   `xcrun devicectl device install app`.
3. Sends a macOS notification either way (success, skipped, or failed) and
   logs details to `~/Library/Logs/HealthTrackerRedeploy/redeploy.log`.

## One-time setup on a new Mac

Update `DEVICE_ID` in the script to the target iPhone's identifier (find it
with `xcrun xctrace list devices`), then create
`~/Library/LaunchAgents/com.arushi.healthtracker.redeploy.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.arushi.healthtracker.redeploy</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>/Users/arushi/HealthTrackerIOS/scripts/redeploy-to-iphone.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>432000</integer>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/Users/arushi/Library/Logs/HealthTrackerRedeploy/launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/arushi/Library/Logs/HealthTrackerRedeploy/launchd.err.log</string>
</dict>
</plist>
```

Then load it:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.arushi.healthtracker.redeploy.plist
```

## Useful commands

Check status:

```bash
launchctl print gui/$(id -u)/com.arushi.healthtracker.redeploy
```

Trigger a run manually (without waiting for the schedule):

```bash
launchctl kickstart gui/$(id -u)/com.arushi.healthtracker.redeploy
```

Tail the log:

```bash
tail -f ~/Library/Logs/HealthTrackerRedeploy/redeploy.log
```

Remove it entirely:

```bash
launchctl bootout gui/$(id -u)/com.arushi.healthtracker.redeploy
rm ~/Library/LaunchAgents/com.arushi.healthtracker.redeploy.plist
```

## The real fix

This script is a stopgap. Enrolling in the paid Apple Developer Program
($99/year) makes provisioning profiles valid for a year instead of 7 days,
which removes the need for this entirely.
