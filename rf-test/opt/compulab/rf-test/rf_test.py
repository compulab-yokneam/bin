#!/usr/bin/env python3
"""Interactive mwifiex RF tests, based on README section 6. No extra modules."""
import argparse
import datetime
import fcntl
import os
from pathlib import Path
import re
import signal


def field(name, default, hint="integer; decimal or 0x hex", allowed=None, low=None, high=None):
    return (name, str(default), hint, allowed, low, high)


def flag(name, default=0):
    return field(name, default, "0=disable, 1=enable", {0, 1})


def default_flag(name, default=-1):
    return field(name, default, "-1=firmware default, 0=disable, 1=enable", {-1, 0, 1})


F = field
FRAME = [flag("Start", 1), F("Rate index", 7), F("Payload pattern", "0xAAA", low=0, high=0xffffffff),
         F("Payload length", "0x100", "1..0x400 bytes", low=1, high=0x400),
         flag("Adjust burst SIFS", 1), F("Burst SIFS", 20, "0..255 us", low=0, high=255),
         flag("Short preamble"), F("Active subchannel", 0, "0=low, 1=upper, 3=both", {0, 1, 3}),
         flag("Short GI"), flag("Advanced coding"), flag("Beamforming"), flag("Greenfield"), flag("STBC"),
         F("Signal bandwidth", 0, "-1=default, 0=20MHz, 1=40MHz, 4=80MHz", {-1, 0, 1, 4})]
AX = [F("Packet count", -1, "-1=default, 1..0xfffffffe", low=-1, high=0xfffffffe),
      F("Max packet extension", -1, "-1=default, 0/8/16 us", {-1, 0, 8, 16}),
      default_flag("Beam change"), default_flag("DCM"), default_flag("Doppler"),
      F("Midamble period", -1, "-1=default, 10 or 20", {-1, 10, 20}),
      F("Queue number", -1, "-1=default, 0..12 or 17..20", set(range(13)) | set(range(17, 21)) | {-1})]
MAC = F("BSSID", "02:00:00:00:00:01", "six hex octets, xx:xx:xx:xx:xx:xx", "mac")
TRIGGER = [flag("Start", 1), flag("Standalone HE TB"), F("Frame control type", 1),
           F("Frame control subtype", 2), F("Duration", 5484), F("Trigger type", 0), F("UL length", 256),
           flag("More trigger frames"), flag("CS required"),
           F("UL bandwidth", 0, "-1=default, 0=20, 1=40, 2=80, 3=160/80+80 MHz", {-1, 0, 1, 2, 3}),
           F("LTF type", 1, "0=1x/1.6us, 1=2x/0.8us, 2=2x/1.6us, 3=4x/3.2us", {0, 1, 2, 3}),
           flag("LTF mode"), F("LTF symbols", 0), flag("UL STBC"), flag("LDPC ESS", 1),
           F("AP TX power", 60, "encoded value 0..61", low=0, high=61),
           F("Pre-FEC padding factor", 1, "1..4", low=1, high=4), flag("Disambiguation"),
           F("Spatial reuse", 65535), flag("Doppler"), F("HE SIG2", 511),
           F("AID12", 5, "12-bit value", low=0, high=4095), F("RU allocation register", 0, "8-bit value", low=0, high=255),
           flag("RU allocation"), flag("Coding type"), F("UL MCS", 0), flag("UL DCM"), F("SS allocation", 0),
           F("Target RSSI ID", 90, "encoded value 0..90", low=0, high=90),
           F("MPDU MU scaling factor", 0, "0=x1, 1=x2, 2=x4, 3=x8", {0, 1, 2, 3}),
           F("TID aggregation limit", 0), flag("AC preferred limit"),
           F("Preferred AC", 0, "0=VO, 1=VI, 2=BE, 3=BK", {0, 1, 2, 3})]
COMMANDS = {
    "rf_test_mode": ("Enter/exit RF test mode", [flag("RF test mode", 1)]),
    "radio_mode": ("Radio mode (2.4G 1x1: 11 0; 5G 1x1: 3 0)", [F("Radio mode 0", 11), F("Radio mode 1", 0)]),
    "tx_antenna": ("TX antenna; match RX path", [F("TX antenna", 1, "1=main/A, 2=aux/B, 3=A+B (chip dependent)", {1, 2, 3})]),
    "rx_antenna": ("RX antenna; match TX path", [F("RX antenna", 1, "1=main/A, 2=aux/B, 3=A+B (chip dependent)", {1, 2, 3})]),
    "band": ("RF band (resets channel to 6 or 36)", [F("Band", 0, "0=2.4GHz, 1=5GHz", {0, 1})]),
    "bw": ("RF bandwidth", [F("Bandwidth", 0, "0=20MHz, 1=40MHz, 4=80MHz", {0, 1, 4})]),
    "channel": ("RF channel", [F("Channel", 6, low=1, high=255)]),
    "get_and_reset_per": ("Get/reset packet error rate", []),
    "tx_power": ("TX power; requires calibration data already loaded", [F("Power", 16, "-15..24 dBm", low=-15, high=24), F("Modulation", 2, "0=CCK, 1=OFDM, 2=MCS", {0, 1, 2}), F("Path", 0, "0=A, 1=B, 2=A+B", {0, 1, 2})]),
    "he_tb_tx": ("HE trigger-based TX (README example power 10 exceeds its stated -11..9 range)", [flag("Enable", 1), F("Queue", 1, "0..7 or 17..20", set(range(8)) | set(range(17, 21))), F("AID", 5), F("MU EDCA timer", 400), F("Power", 9, "-11..9 dBm", low=-11, high=9)]),
    "tx_continuous": ("Continuous wave or continuous packets", [flag("Start", 1), flag("Continuous wave", 1), F("Payload pattern", "0xAAA", low=0, high=0xffffffff), flag("CS mode"), F("Active subchannel", 3, "0=low, 1=upper, 3=both", {0, 1, 3}), F("Rate index", 7)]),
    "tx_frame": ("TX frames (11ax or legacy)", FRAME + AX + [MAC]),
    "trigger_frame": ("Configure trigger frame; transmission uses tx_frame", TRIGGER),
}
STOPPABLE = {"he_tb_tx", "tx_continuous", "tx_frame", "trigger_frame"}


def validate(value, spec):
    name, _, _, allowed, low, high = spec
    if allowed == "mac":
        if not re.fullmatch(r"(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}", value):
            raise ValueError(f"{name}: require six hex octets")
        return value.lower()
    try:
        n = int(value, 16) if value.lower().startswith(("0x", "-0x")) else int(value, 10)
    except ValueError:
        raise ValueError(f"{name}: require a decimal or hex integer") from None
    if allowed is not None and n not in allowed:
        raise ValueError(f"{name}: allowed values {sorted(allowed)}")
    if (low is not None and n < low) or (high is not None and n > high) or (name == "Packet count" and n == 0):
        raise ValueError(f"{name}: outside documented range ({spec[2]})")
    return value


def parse_command(line):
    key, sep, rest = line.strip().partition("=")
    if key not in COMMANDS:
        raise ValueError("Unknown command; type help for supported commands")
    values = rest.split() if sep else []
    specs = COMMANDS[key][1]
    if key in STOPPABLE and values == ["0"]:
        return key, values
    if key == "tx_frame":
        if len(values) == 4:  # README trigger-frame transmission example
            specs = FRAME[:4]
        elif len(values) == len(FRAME) + 1:
            specs = FRAME + [MAC]
    if len(values) != len(specs):
        raise ValueError(f"{key}: expected {len(specs)} parameters, received {len(values)}")
    return key, [validate(v, s) for v, s in zip(values, specs)]


class Session:
    def __init__(self, config, dry_run, log):
        self.config, self.dry_run = config, dry_run
        self.active = set()
        self.entered = False
        self.log = log.open("a", buffering=1)

    def record(self, message):
        self.log.write(f"{datetime.datetime.now().astimezone().isoformat()} {message}\n")

    def status(self):
        content = self.config.read_text()
        print(content, end="" if content.endswith("\n") else "\n")
        self.record("STATUS\n" + content)
        return content

    def write(self, key, values):
        command = key + ("=" + " ".join(values) if values else "")
        print(("DRY RUN: " if self.dry_run else "WRITE: ") + command)
        self.record(("DRY RUN " if self.dry_run else "WRITE ") + command)
        if not self.dry_run:
            try:
                with self.config.open("w") as target:
                    target.write(command + "\n")
            except OSError as exc:
                self.record(f"ERROR {exc}")
                raise
        if key in STOPPABLE:
            if values[0] == "0":
                self.active.discard(key)
            else:
                self.active.add(key)
        if key == "rf_test_mode":
            self.entered = values == ["1"]
            if not self.entered:
                print("Firmware must be reset before normal Wi-Fi connectivity can resume.")

    def stop(self, all_commands=False):
        # Stop frames before removing their trigger configuration.
        for key in ("tx_frame", "tx_continuous", "he_tb_tx", "trigger_frame"):
            if all_commands or key in self.active:
                try:
                    self.write(key, ["0"])
                except OSError as exc:
                    print(f"Could not stop {key}: {exc}")

    def issue(self, line):
        key, values = parse_command(line)
        if key == "rf_test_mode" and values == ["0"]:
            self.stop()
        if key in {"tx_continuous", "tx_frame"} and values[0] == "1":
            # README requires stopping ongoing TX before either start operation.
            self.write("tx_frame", ["0"])
            self.write("tx_continuous", ["0"])
        self.write(key, values)
        if not self.dry_run:
            self.status()  # Includes firmware results; a successful write alone is not proof of support.

    def close(self):
        self.stop()
        if self.entered:
            try:
                self.write("rf_test_mode", ["0"])
            except OSError as exc:
                print(f"Could not exit RF test mode: {exc}")
        self.log.close()


def guided(key):
    print(COMMANDS[key][0])
    specs = COMMANDS[key][1]
    if key == "tx_frame":
        kind = input("Frame format [ax/legacy/short; default ax]: ").strip().lower() or "ax"
        if kind not in {"ax", "legacy", "short"}:
            raise ValueError("Choose ax, legacy, or short")
        specs = {"ax": FRAME + AX + [MAC], "legacy": FRAME + [MAC], "short": FRAME[:4]}[kind]
    values = []
    for spec in specs:
        while True:
            value = input(f"  {spec[0]} ({spec[2]}) [{spec[1]}]: ").strip() or spec[1]
            if value.lower() == "cancel":
                return None
            try:
                values.append(validate(value, spec))
                break
            except ValueError as exc:
                print(exc)
        if key in STOPPABLE and len(values) == 1 and values[0] == "0":
            break
    return key + ("=" + " ".join(values) if values else "")


def menu():
    print("\nRF test commands (choose a number for guided parameters):")
    for i, (key, (description, _)) in enumerate(COMMANDS.items(), 1):
        print(f"  {i:2}. {key}: {description}")
    print("  status | stop | help | docs | quit")
    print("Or enter a command directly, e.g. band=0. Type cancel during prompts to cancel.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path("/proc/mwlan/adapter0/config"))
    parser.add_argument("--dry-run", action="store_true", help="print commands without writing to procfs")
    parser.add_argument("--log", type=Path, default=Path(__file__).resolve().parent / "rf-test.log")
    args = parser.parse_args()
    if not args.config.is_file():
        parser.error(f"Missing driver config {args.config}; load the mwifiex driver or use --config")
    if not args.dry_run and os.geteuid() != 0:
        parser.error("Run as root, or use --dry-run")
    # Coordinate sessions per adapter, including when an alternate log path is used.
    lock_name = re.sub(r"[^A-Za-z0-9_.-]", "_", str(args.config.resolve()))
    lock = open(Path("/tmp") / ("compulab-rf-test-" + lock_name + ".lock"), "a")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        parser.error("Another RF test session is using this adapter")
    session = Session(args.config, args.dry_run, args.log)
    def interrupted(signum, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, interrupted)
    print(f"Config: {args.config}\nLog: {args.log}")
    print("Wi-Fi must be disconnected and uAP BSS inactive before entering RF mode.")
    print("Start with rf_test_mode=1. Commands depend on chipset and firmware support.")
    print("Quit/Ctrl-C stops TX started here and exits RF mode if entered here.")
    print("Exiting RF mode requires a firmware reset before normal Wi-Fi operation.")
    try:
        session.status()
        menu()
        while True:
            try:
                line = input("rf-test> ").strip()
                if not line:
                    continue
                if line in {"q", "quit", "exit"}:
                    break
                if line in {"help", "?", "menu"}:
                    menu()
                elif line == "docs":
                    print(Path(__file__).with_name("RF_COMMANDS.txt").read_text())
                elif line == "status":
                    session.status()
                elif line == "stop":
                    session.stop(all_commands=True)
                else:
                    if line.isdecimal():
                        index = int(line) - 1
                        if not 0 <= index < len(COMMANDS):
                            raise ValueError("Invalid menu number")
                        line = guided(list(COMMANDS)[index])
                    if line:
                        session.issue(line)
            except (ValueError, OSError) as exc:
                print(f"ERROR: {exc}")
    except (EOFError, KeyboardInterrupt):
        print("\nClosing RF test session.")
    finally:
        session.close()
        lock.close()


if __name__ == "__main__":
    main()
