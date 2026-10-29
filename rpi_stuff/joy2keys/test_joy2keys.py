#!/usr/bin/env python3
"""joy2keys tests. Translator tests are pure; FakeStick tests need /dev/uinput (run on the Pi)."""
import errno
import fcntl
import os
import re
import struct
import subprocess
import sys
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import joy2keys as j  # noqa: E402

K = j.KEY_CODES
BTN = list(range(0x120, 0x12C))  # BTN_TRIGGER..BTN_BASE6, as on the DragonRise
ABS = [0, 1, 2, 3, 5, 16, 17]
ABSINFO = {c: (0, 255) for c in ABS}
ABSINFO[16] = ABSINFO[17] = (-1, 1)


def translator():
    return j.Translator(j.js_button_codes(BTN), ABS, ABSINFO)


class TranslatorTest(unittest.TestCase):
    def test_buttons_map_by_js_number(self):
        tr = translator()
        want = {289: "KEY_H", 288: "KEY_J", 292: "KEY_K", 299: "KEY_F", 291: "KEY_G", 290: "KEY_N"}
        for code, name in want.items():
            self.assertEqual(tr.feed(j.EV_KEY, code, 1), [(K[name], 1)])
            self.assertEqual(tr.feed(j.EV_KEY, code, 0), [(K[name], 0)])

    def test_hold_and_autorepeat_value_ignored(self):
        tr = translator()
        self.assertEqual(tr.feed(j.EV_KEY, 288, 1), [(K["KEY_J"], 1)])
        self.assertEqual(tr.feed(j.EV_KEY, 288, 2), [])
        self.assertEqual(tr.feed(j.EV_KEY, 288, 1), [])
        self.assertEqual(tr.feed(j.EV_KEY, 288, 0), [(K["KEY_J"], 0)])

    def test_unmapped_button_ignored(self):
        self.assertEqual(translator().feed(j.EV_KEY, 293, 1), [])

    def test_rotated_stick(self):
        tr = translator()
        self.assertEqual(tr.feed(j.EV_ABS, 1, 0), [(K["KEY_UP"], 1)])
        self.assertEqual(tr.feed(j.EV_ABS, 1, 127), [(K["KEY_UP"], 0)])
        self.assertEqual(tr.feed(j.EV_ABS, 1, 255), [(K["KEY_DOWN"], 1)])
        self.assertEqual(tr.feed(j.EV_ABS, 1, 0), [(K["KEY_DOWN"], 0), (K["KEY_UP"], 1)])
        self.assertEqual(tr.feed(j.EV_ABS, 0, 255), [(K["KEY_RIGHT"], 1)])
        self.assertEqual(tr.feed(j.EV_ABS, 0, 128), [(K["KEY_RIGHT"], 0)])
        self.assertEqual(tr.feed(j.EV_ABS, 0, 0), [(K["KEY_LEFT"], 1)])

    def test_deadzone_hysteresis(self):
        tr = translator()
        self.assertEqual(tr.feed(j.EV_ABS, 1, 90), [])        # inside press threshold
        self.assertEqual(tr.feed(j.EV_ABS, 1, 40), [(K["KEY_UP"], 1)])
        self.assertEqual(tr.feed(j.EV_ABS, 1, 70), [])        # between thresholds: held
        self.assertEqual(tr.feed(j.EV_ABS, 1, 110), [(K["KEY_UP"], 0)])

    def test_other_axes_ignored_and_release_all(self):
        tr = translator()
        self.assertEqual(tr.feed(j.EV_ABS, 2, 0), [])
        self.assertEqual(tr.feed(j.EV_ABS, 16, -1), [])
        tr.feed(j.EV_KEY, 289, 1)
        tr.feed(j.EV_ABS, 0, 0)
        self.assertEqual(sorted(tr.release_all()), sorted([(K["KEY_H"], 0), (K["KEY_LEFT"], 0)]))
        self.assertEqual(tr.release_all(), [])


class FakeStick:
    """uinput device with the DragonRise's button and axis layout."""

    def __init__(self):
        self.fd = os.open("/dev/uinput", os.O_WRONLY)
        for ev in (j.EV_KEY, j.EV_ABS):
            fcntl.ioctl(self.fd, j.UI_SET_EVBIT, ev)
        for code in BTN:
            fcntl.ioctl(self.fd, j.UI_SET_KEYBIT, code)
        for code in ABS:
            fcntl.ioctl(self.fd, j._ioc(1, "U", 103, 4), code)  # UI_SET_ABSBIT
        mx, mn = [0] * 64, [0] * 64
        for code, (lo, hi) in ABSINFO.items():
            mn[code], mx[code] = lo, hi
        dev = struct.pack("80sHHHHi", b"joy2keys test stick", 3, 0x1234, 0x5678, 1, 0)
        dev += struct.pack("64i", *mx) + struct.pack("64i", *mn) + b"\0" * 512
        os.write(self.fd, dev)
        fcntl.ioctl(self.fd, j.UI_DEV_CREATE)

    def send(self, etype, code, value):
        os.write(self.fd, struct.pack(j.EVENT_FMT, 0, 0, etype, code, value)
                 + struct.pack(j.EVENT_FMT, 0, 0, j.EV_SYN, 0, 0))

    def close(self):
        fcntl.ioctl(self.fd, j.UI_DEV_DESTROY)
        os.close(self.fd)


def event_node(name, timeout=3.0):
    end = time.time() + timeout
    while time.time() < end:
        with open("/proc/bus/input/devices") as f:
            for block in f.read().split("\n\n"):
                if 'N: Name="%s"' % name in block:
                    m = re.search(r"Handlers=.*?(event\d+)", block)
                    if m and os.access("/dev/input/" + m.group(1), os.R_OK):
                        return "/dev/input/" + m.group(1)
        time.sleep(0.05)
    return None


def read_keys(fd, timeout=1.0):
    out, end = [], time.time() + timeout
    while time.time() < end:
        try:
            data = os.read(fd, j.EVENT_SIZE * 64)
        except BlockingIOError:
            time.sleep(0.005)
            continue
        except OSError as exc:
            if exc.errno == errno.ENODEV:  # device destroyed
                break
            raise
        for off in range(0, len(data), j.EVENT_SIZE):
            _, _, t, c, v = struct.unpack_from(j.EVENT_FMT, data, off)
            if t == j.EV_KEY:
                out.append((c, v))
    return out


@unittest.skipUnless(os.access("/dev/uinput", os.W_OK), "needs /dev/uinput")
class DaemonOnKernelTest(unittest.TestCase):
    def setUp(self):
        self.stick = FakeStick()
        self.src = event_node("joy2keys test stick")
        self.stick.send(j.EV_ABS, 0, 127)  # centre first; the kernel drops repeated values
        self.stick.send(j.EV_ABS, 1, 127)
        self.proc = subprocess.Popen([sys.executable, os.path.join(HERE, "joy2keys.py"),
                                      "--device", self.src], stderr=subprocess.PIPE)
        self.kbd = event_node(j.VIRTUAL_NAME.decode())
        self.assertIsNotNone(self.kbd, "virtual keyboard did not appear")
        self.kfd = os.open(self.kbd, os.O_RDONLY | os.O_NONBLOCK)
        time.sleep(0.3)  # let the daemon grab

    def tearDown(self):
        os.close(self.kfd)
        if self.proc.poll() is None:
            self.proc.terminate()
            self.proc.wait(5)
        self.proc.stderr.close()
        self.stick.close()

    def test_forwarding_grab_and_cleanup(self):
        probe = os.open(self.src, os.O_RDONLY)
        with self.assertRaises(OSError) as cm:
            fcntl.ioctl(probe, j.EVIOCGRAB, 1)
        self.assertEqual(cm.exception.errno, errno.EBUSY)
        os.close(probe)

        self.stick.send(j.EV_KEY, 289, 1)
        self.stick.send(j.EV_ABS, 1, 0)
        self.stick.send(j.EV_ABS, 1, 127)
        self.stick.send(j.EV_KEY, 289, 0)
        self.assertEqual(read_keys(self.kfd), [(K["KEY_H"], 1), (K["KEY_UP"], 1),
                                               (K["KEY_UP"], 0), (K["KEY_H"], 0)])

        self.stick.send(j.EV_KEY, 288, 1)  # Blue held at SIGTERM: released on exit
        self.assertEqual(read_keys(self.kfd, 0.5), [(K["KEY_J"], 1)])
        self.proc.terminate()
        self.assertIn((K["KEY_J"], 0), read_keys(self.kfd, 1.0))
        self.assertEqual(self.proc.wait(5), 0)
        self.assertIsNone(event_node(j.VIRTUAL_NAME.decode(), 0.5))
        probe = os.open(self.src, os.O_RDONLY)
        fcntl.ioctl(probe, j.EVIOCGRAB, 1)  # free again
        os.close(probe)


@unittest.skipUnless(os.access("/dev/uinput", os.W_OK), "needs /dev/uinput")
class UnplugTest(unittest.TestCase):
    def test_replug_resumes(self):
        link = os.path.join(HERE, "stick-link")  # stands in for the by-id symlink
        stick = FakeStick()
        os.symlink(event_node("joy2keys test stick"), link)
        proc = subprocess.Popen([sys.executable, os.path.join(HERE, "joy2keys.py"),
                                 "--device", link], stderr=subprocess.PIPE)
        try:
            kfd = os.open(event_node(j.VIRTUAL_NAME.decode()), os.O_RDONLY | os.O_NONBLOCK)
            time.sleep(0.3)
            stick.send(j.EV_KEY, 289, 1)
            self.assertEqual(read_keys(kfd, 0.4), [(K["KEY_H"], 1)])
            stick.close()  # unplug while Yellow is held: the key is released
            os.unlink(link)
            self.assertEqual(read_keys(kfd, 0.4), [(K["KEY_H"], 0)])
            stick = FakeStick()
            os.symlink(event_node("joy2keys test stick"), link)
            time.sleep(1.2)
            stick.send(j.EV_KEY, 291, 1)
            self.assertEqual(read_keys(kfd, 0.4), [(K["KEY_G"], 1)])
            self.assertIsNone(proc.poll())
            os.close(kfd)
        finally:
            proc.terminate()
            proc.wait(5)
            proc.stderr.close()
            stick.close()
            if os.path.lexists(link):
                os.unlink(link)


if __name__ == "__main__":
    unittest.main(verbosity=2)
