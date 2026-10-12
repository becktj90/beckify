#!/usr/bin/env python3
"""Create and boot a named simulator for the Beckify Drive screenshot job.

Usage: prepare_drive_simulator.py <iOS version> <device type name>
Writes destination=... to $GITHUB_OUTPUT. The runtime is installed if missing.
"""
import json
import os
import subprocess
import sys

version, device_name = sys.argv[1], sys.argv[2]


def simctl_json(*args):
    return json.loads(subprocess.check_output(["xcrun", "simctl", "list", *args, "--json"], text=True))


def find_runtime():
    return next(
        (r for r in simctl_json("runtimes")["runtimes"]
         if r.get("isAvailable") and r["version"] == version),
        None,
    )


runtime = find_runtime()
if runtime is None:
    subprocess.run(["xcodebuild", "-downloadPlatform", "iOS", "-buildVersion", version], check=True)
    runtime = find_runtime()
if runtime is None:
    raise SystemExit(f"iOS {version} simulator runtime is unavailable after installation")

types = simctl_json("devicetypes")["devicetypes"]
device_type = next((t for t in types if t["name"] == device_name), None)
if device_type is None:
    names = ", ".join(t["name"] for t in types)
    raise SystemExit(f"No device type named {device_name!r}. Available: {names}")

udid = subprocess.check_output(
    ["xcrun", "simctl", "create", f"Drive {device_name}", device_type["identifier"], runtime["identifier"]],
    text=True,
).strip()
subprocess.run(["xcrun", "simctl", "boot", udid], check=True)
subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True)
with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
    output.write(f"destination=platform=iOS Simulator,id={udid}\n")
    output.write(f"udid={udid}\n")
print(f"Ready: {device_name}, iOS {version}, {udid}")
