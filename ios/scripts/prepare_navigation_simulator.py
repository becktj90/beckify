#!/usr/bin/env python3
"""Create and boot the requested iPhone simulator for the navigation UI suite."""
import json
import os
import subprocess
import sys

version = sys.argv[1]


def find_runtime():
    result = subprocess.check_output(
        ["xcrun", "simctl", "list", "runtimes", "--json"], text=True
    )
    return next(
        (runtime for runtime in json.loads(result)["runtimes"]
         if runtime.get("isAvailable") and runtime["version"] == version),
        None,
    )


runtime = find_runtime()
if runtime is None:
    subprocess.run(
        ["xcodebuild", "-downloadPlatform", "iOS", "-buildVersion", version], check=True
    )
    runtime = find_runtime()
if runtime is None:
    raise SystemExit(f"iOS {version} simulator runtime is unavailable after installation")

simulator_id = subprocess.check_output(
    ["xcrun", "simctl", "create", "Beckify Navigation",
     "com.apple.CoreSimulator.SimDeviceType.iPhone-16", runtime["identifier"]],
    text=True,
).strip()
subprocess.run(["xcrun", "simctl", "boot", simulator_id], check=True)
subprocess.run(["xcrun", "simctl", "bootstatus", simulator_id, "-b"], check=True)
with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
    output.write(f"destination=platform=iOS Simulator,id={simulator_id}\n")
print(f"Ready: iPhone 16, iOS {version}, {simulator_id}")
