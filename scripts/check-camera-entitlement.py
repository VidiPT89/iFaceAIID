#!/usr/bin/env python3
"""Verify camera access survives signing a Hardened Runtime macOS build."""
import plistlib
import subprocess
import sys

result = subprocess.run(["codesign", "-d", "--entitlements", "-", "--xml", sys.argv[1]], capture_output=True)
try:
    entitlements = plistlib.loads(result.stdout)
except Exception:
    raise SystemExit("FAIL: signed app has no readable entitlements")
assert entitlements.get("com.apple.security.device.camera") is True, "FAIL: signed app lacks camera entitlement"
print("PASS: signed app includes camera entitlement")
