#!/usr/bin/env python3
"""Verify FlowClip keeps the sandbox that owns its saved history and settings."""

import plistlib
import subprocess
import sys
from pathlib import Path

app = Path(sys.argv[1])
subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)], check=True)
raw = subprocess.check_output(["/usr/bin/codesign", "-d", "--entitlements", ":-", str(app)])
if b"<?xml" not in raw:
    sys.exit("FlowClip has no signed entitlements; existing history and settings would be inaccessible")
start = raw.index(b"<?xml")
end = raw.index(b"</plist>", start) + len(b"</plist>")
entitlements = plistlib.loads(raw[start:end])
with (app / "Contents/Info.plist").open("rb") as source:
    bundle_id = plistlib.load(source)["CFBundleIdentifier"]

if bundle_id != "com.gityeop.FlowClip":
    sys.exit(f"Unexpected FlowClip bundle identifier: {bundle_id}")
if entitlements.get("com.apple.security.app-sandbox") is not True:
    sys.exit("FlowClip is missing App Sandbox; existing history and settings would be inaccessible")
if entitlements.get("com.apple.security.files.user-selected.read-only") is not True:
    sys.exit("FlowClip is missing user-selected read-only access")
expected = {f"{bundle_id}-spks", f"{bundle_id}-spki"}
actual = set(entitlements.get("com.apple.security.temporary-exception.mach-lookup.global-name", []))
if actual != expected:
    sys.exit(f"Unexpected Sparkle mach-lookup entitlements: {sorted(actual)}")
print(f"Verified FlowClip sandbox: {app}")
