#!/usr/bin/env python3
"""Cabinet USB encoder -> virtual keyboard for mkxp-z (stdlib only, Python 3.7).

Grabs the DragonRise joystick so SDL never sees it and replays it as the keys
the game reads (docs/controls.md). Run in the background while the game runs.
"""
import errno
import fcntl
import os
import select
import signal
import struct
import sys
import time

# ---- Mapping (one table). Button numbers are /dev/input/js0 numbers. ----
BUTTON_KEYS = {
    1: "KEY_H",   # Yellow
    0: "KEY_J",   # Blue (hold = run)
    4: "KEY_K",   # Orange
    11: "KEY_F",  # White
    3: "KEY_G",   # Green
    2: "KEY_N",   # Pink
}
# Axis index (js numbering) -> (key when value is low, key when value is high).
# The stick is mounted rotated: axis 0 low = right, axis 1 low = up.
AXIS_KEYS = {
    0: ("KEY_LEFT", "KEY_RIGHT"),
    1: ("KEY_UP", "KEY_DOWN"),
}
PRESS_FRACTION = 0.5    # of half-range from centre, to press an arrow
RELEASE_FRACTION = 0.3  # back inside this, the arrow is released
DEVICE = "/dev/input/by-id/usb-DragonRise_Inc._Generic_USB_Joystick-event-joystick"
VIRTUAL_NAME = b"Desert Town joy2keys"

# ---- Linux input constants ----
EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
SYN_REPORT = 0
KEY_CODES = {
    "KEY_H": 35, "KEY_J": 36, "KEY_K": 37, "KEY_F": 33, "KEY_G": 34, "KEY_N": 49,
    "KEY_UP": 103, "KEY_LEFT": 105, "KEY_RIGHT": 106, "KEY_DOWN": 108,
}
BTN_MISC, KEY_MAX, ABS_MAX = 0x100, 0x2FF, 0x3F
EVENT_FMT = "llHHi"  # struct input_event: timeval, type, code, value
EVENT_SIZE = struct.calcsize(EVENT_FMT)


def _ioc(direction, typ, nr, size):
    return (direction << 30) | (size << 16) | (ord(typ) << 8) | nr


def EVIOCGBIT(ev, length):
    return _ioc(2, "E", 0x20 + ev, length)


def EVIOCGABS(axis):
    return _ioc(2, "E", 0x40 + axis, 24)


EVIOCGRAB = _ioc(1, "E", 0x90, 4)
UI_SET_EVBIT = _ioc(1, "U", 100, 4)
UI_SET_KEYBIT = _ioc(1, "U", 101, 4)
UI_DEV_CREATE = _ioc(0, "U", 1, 0)
UI_DEV_DESTROY = _ioc(0, "U", 2, 0)


def log(msg):
    sys.stderr.write("%s joy2keys: %s\n" % (time.strftime("%H:%M:%S"), msg))
    sys.stderr.flush()


def _bits(fd, ev, maxcode):
    buf = bytearray((maxcode + 8) // 8)
    fcntl.ioctl(fd, EVIOCGBIT(ev, len(buf)), buf)
    return [c for c in range(maxcode + 1) if buf[c // 8] & (1 << (c % 8))]


def js_button_codes(key_codes):
    """joydev numbers buttons BTN_MISC..KEY_MAX first, then 0..BTN_MISC-1."""
    return [c for c in key_codes if c >= BTN_MISC] + [c for c in key_codes if c < BTN_MISC]


class Translator:
    """Pure state machine: raw evdev events in, (key, value) changes out."""

    def __init__(self, button_codes, abs_codes, absinfo):
        self.buttons = {}
        for num, name in BUTTON_KEYS.items():
            if num < len(button_codes):
                self.buttons[button_codes[num]] = KEY_CODES[name]
        self.axes = {}
        for num, (low, high) in AXIS_KEYS.items():
            if num < len(abs_codes):
                lo, hi = absinfo[abs_codes[num]]
                self.axes[abs_codes[num]] = ((lo + hi) / 2.0, (hi - lo) / 2.0,
                                             KEY_CODES[low], KEY_CODES[high])
        self.axis_state = {}  # abs code -> key code currently held, or None
        self.down = set()

    def _set(self, key, value, out):
        if value and key not in self.down:
            self.down.add(key)
            out.append((key, 1))
        elif not value and key in self.down:
            self.down.discard(key)
            out.append((key, 0))

    def feed(self, etype, code, value):
        out = []
        if etype == EV_KEY and code in self.buttons and value in (0, 1):
            self._set(self.buttons[code], value, out)
        elif etype == EV_ABS and code in self.axes:
            centre, half, low_key, high_key = self.axes[code]
            off = (value - centre) / half if half else 0.0
            held = self.axis_state.get(code)
            want = held
            if off <= -PRESS_FRACTION:
                want = low_key
            elif off >= PRESS_FRACTION:
                want = high_key
            elif abs(off) < RELEASE_FRACTION:
                want = None
            if want != held:
                if held is not None:
                    self._set(held, 0, out)
                if want is not None:
                    self._set(want, 1, out)
                self.axis_state[code] = want
        return out

    def release_all(self):
        out = []
        for key in sorted(self.down):
            out.append((key, 0))
        self.down.clear()
        self.axis_state.clear()
        return out


class VirtualKeyboard:
    def __init__(self):
        self.fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
        fcntl.ioctl(self.fd, UI_SET_EVBIT, EV_KEY)
        # Keys 1..31 too, so udev tags it ID_INPUT_KEYBOARD and SDL treats it as one.
        for code in sorted(set(range(1, 32)) | set(KEY_CODES.values())):
            fcntl.ioctl(self.fd, UI_SET_KEYBIT, code)
        # struct uinput_user_dev: name[80], input_id, ff_effects_max, 4 x absX[64]
        dev = struct.pack("80sHHHHi", VIRTUAL_NAME, 0x06, 0, 0, 1, 0)
        os.write(self.fd, dev + b"\0" * (4 * 64 * 4))
        fcntl.ioctl(self.fd, UI_DEV_CREATE)

    def emit(self, changes):
        if not changes:
            return
        now = time.time()
        sec, usec = int(now), int((now % 1) * 1e6)
        data = b"".join(struct.pack(EVENT_FMT, sec, usec, EV_KEY, k, v) for k, v in changes)
        data += struct.pack(EVENT_FMT, sec, usec, EV_SYN, SYN_REPORT, 0)
        os.write(self.fd, data)

    def close(self):
        try:
            fcntl.ioctl(self.fd, UI_DEV_DESTROY)
        finally:
            os.close(self.fd)


def open_source(path):
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
    try:
        fcntl.ioctl(fd, EVIOCGRAB, 1)
        keys = js_button_codes(_bits(fd, EV_KEY, KEY_MAX))
        abs_codes = _bits(fd, EV_ABS, ABS_MAX)
        absinfo = {}
        for code in abs_codes:
            buf = bytearray(24)
            fcntl.ioctl(fd, EVIOCGABS(code), buf)
            _, lo, hi, _, _, _ = struct.unpack("6i", bytes(buf))
            absinfo[code] = (lo, hi)
    except Exception:
        os.close(fd)
        raise
    return fd, Translator(keys, abs_codes, absinfo)


def ungrab(fd):
    try:
        fcntl.ioctl(fd, EVIOCGRAB, 0)
    except OSError:
        pass
    os.close(fd)


def _on_term(signum, _frame):
    raise SystemExit(0)


def run(path, parent):
    kbd = VirtualKeyboard()
    log("virtual keyboard created")
    src, tr = None, None
    try:
        while True:
            if parent and os.getppid() != parent:
                log("parent gone, exiting")
                return 0
            if src is None:
                try:
                    src, tr = open_source(path)
                    log("grabbed %s; buttons %s axes %s" % (
                        path, sorted(tr.buttons.items()), sorted(tr.axes)))
                except OSError as exc:
                    if exc.errno == errno.EBUSY:
                        log("device already grabbed by another process")
                        return 1
                    time.sleep(0.5)  # unplugged: wait for it to come back
                    continue
            ready, _, _ = select.select([src], [], [], 1.0)
            if not ready:
                continue
            try:
                data = os.read(src, EVENT_SIZE * 64)
            except OSError as exc:
                if exc.errno in (errno.EAGAIN, errno.EINTR):
                    continue
                log("device lost (%s), waiting" % exc.strerror)
                kbd.emit(tr.release_all())
                os.close(src)
                src = None
                continue
            changes = []
            for off in range(0, len(data) - EVENT_SIZE + 1, EVENT_SIZE):
                _, _, etype, code, value = struct.unpack_from(EVENT_FMT, data, off)
                changes.extend(tr.feed(etype, code, value))
            kbd.emit(changes)
    finally:
        if tr is not None:
            try:
                kbd.emit(tr.release_all())
                time.sleep(0.05)  # let readers see the release before the device vanishes
            except OSError:
                pass
        if src is not None:
            ungrab(src)
        kbd.close()
        log("stopped, grab released, keyboard destroyed")


def main(argv):
    path, parent = DEVICE, 0
    args = list(argv)
    while args:
        arg = args.pop(0)
        if arg == "--device":
            path = args.pop(0)
        elif arg == "--parent":
            parent = int(args.pop(0))
        else:
            sys.stderr.write("usage: joy2keys.py [--device PATH] [--parent PID]\n")
            return 2
    signal.signal(signal.SIGTERM, _on_term)
    signal.signal(signal.SIGINT, _on_term)
    signal.signal(signal.SIGHUP, _on_term)
    return run(path, parent)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
