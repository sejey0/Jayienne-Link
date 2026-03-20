#!/usr/bin/env python3
"""
ADB Wireless Pairing Helper
Simple and reliable wireless debugging connection.
"""

import socket
import subprocess
import sys
import re

def get_local_ip():
    """Get the local IP address of this machine."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def get_adb_path():
    """Find adb executable."""
    import os
    # Try common locations
    paths = [
        os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"),
        "adb"
    ]
    for p in paths:
        try:
            result = subprocess.run([p, "version"], capture_output=True, timeout=5)
            if result.returncode == 0:
                return p
        except:
            continue
    return "adb"

def scan_for_devices(local_ip):
    """Scan local network for ADB devices."""
    print("\n  Scanning network for devices...")

    # Get the network prefix (e.g., 192.168.1)
    prefix = '.'.join(local_ip.split('.')[:-1])

    adb = get_adb_path()
    found = []

    # Check adb devices first
    try:
        result = subprocess.run([adb, "devices"], capture_output=True, text=True, timeout=5)
        lines = result.stdout.strip().split('\n')[1:]
        for line in lines:
            if line.strip() and 'device' in line:
                device_id = line.split()[0]
                if ':' in device_id:  # It's a network device
                    found.append(device_id)
                    print(f"    Found connected: {device_id}")
    except:
        pass

    return found

def main():
    print()
    print("=" * 55)
    print("   ADB Wireless Debugging - Easy Connect")
    print("=" * 55)
    print()

    local_ip = get_local_ip()
    adb = get_adb_path()

    print(f"  Your PC IP: {local_ip}")
    print()

    # Check for already connected devices
    existing = scan_for_devices(local_ip)
    if existing:
        print(f"\n  Already connected wirelessly to {len(existing)} device(s)!")
        return 0

    print()
    print("-" * 55)
    print("  STEP 1: On your Android phone")
    print("-" * 55)
    print("  1. Go to Settings > Developer options")
    print("  2. Tap 'Wireless debugging' and enable it")
    print("  3. Make sure phone is on same WiFi as this PC")
    print()

    print("-" * 55)
    print("  STEP 2: Get pairing info from phone")
    print("-" * 55)
    print("  Tap 'Pair device with pairing code'")
    print("  You'll see an IP:Port and a 6-digit code")
    print()

    # Get pairing info
    pair_addr = input("  Enter pairing IP:Port (e.g., 192.168.1.100:37123): ").strip()
    if not pair_addr:
        print("  Cancelled.")
        return 1

    pair_code = input("  Enter 6-digit pairing code: ").strip()
    if not pair_code:
        print("  Cancelled.")
        return 1

    print()
    print("  Pairing...")

    try:
        result = subprocess.run(
            [adb, "pair", pair_addr, pair_code],
            capture_output=True,
            text=True,
            timeout=30
        )

        if "Successfully paired" in result.stdout or "Successfully paired" in result.stderr:
            print("  Pairing successful!")
        else:
            print(f"  Pairing result: {result.stdout} {result.stderr}")
            if "error" in result.stderr.lower() or "failed" in result.stderr.lower():
                print("  Pairing may have failed. Check the code and try again.")
                return 1
    except subprocess.TimeoutExpired:
        print("  Pairing timed out. Try again.")
        return 1
    except Exception as e:
        print(f"  Error: {e}")
        return 1

    print()
    print("-" * 55)
    print("  STEP 3: Connect to device")
    print("-" * 55)
    print("  On your phone's Wireless debugging screen,")
    print("  look for the IP address & port (NOT the pairing one)")
    print()

    connect_addr = input("  Enter connect IP:Port (e.g., 192.168.1.100:43567): ").strip()
    if not connect_addr:
        print("  Cancelled.")
        return 1

    print()
    print("  Connecting...")

    try:
        result = subprocess.run(
            [adb, "connect", connect_addr],
            capture_output=True,
            text=True,
            timeout=30
        )

        output = result.stdout + result.stderr
        if "connected" in output.lower():
            print("  Connected successfully!")
            print()
            print("=" * 55)
            print("  Ready! You can now run Flutter apps wirelessly.")
            print("=" * 55)
            return 0
        else:
            print(f"  Connection result: {output}")
            return 1
    except Exception as e:
        print(f"  Error: {e}")
        return 1

if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n  Cancelled.")
        sys.exit(0)
