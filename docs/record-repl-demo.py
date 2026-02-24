#!/usr/bin/env python3
"""
Record the query-json REPL demo as an asciinema .cast file.

Spawns the REPL in a PTY with a minimal terminal emulator that responds
to terminal capability queries (DA, DSR, DECRQM, Kitty graphics/keyboard).

Usage:
    asciinema rec --cols 100 --rows 40 \
        -c "python3 docs/record-repl-demo.py" \
        docs/repl-demo.cast
"""

import os
import pty
import re
import sys
import time
import select
import struct
import fcntl
import termios
import threading

TYPE_SPEED = 0.08

TERMINAL_RESPONSES = {
    b'\x1b[c':       b'\x1b[?62;22c',
    b'\x1b[>0q':     b'\x1bP>|xterm(388)\x1b\\',
    b'\x1b[?u':      b'\x1b[?0u',
}

def handle_decrqm(data):
    """Respond to DECRQM (Request Mode) queries: ESC[?{n}$p -> ESC[?{n};0$y"""
    results = []
    for m in re.finditer(rb'\x1b\[\?(\d+)\$p', data):
        mode = m.group(1)
        results.append((m.start(), m.end(), b'\x1b[?' + mode + b';0$y'))
    return results

def handle_dsr(data):
    """Respond to DSR (cursor position): ESC[6n -> ESC[1;1R"""
    results = []
    for m in re.finditer(rb'\x1b\[6n', data):
        results.append((m.start(), m.end(), b'\x1b[1;1R'))
    for m in re.finditer(rb'\x1b\[\?996n', data):
        results.append((m.start(), m.end(), b''))
    return results

def handle_kitty_graphics(data):
    """Respond to Kitty graphics queries."""
    results = []
    for m in re.finditer(rb'\x1b_Gi=(\d+)[^\\]*\x1b\\\\', data):
        gid = m.group(1)
        results.append((m.start(), m.end(), b'\x1b_Gi=' + gid + b';ENOTSUP\x1b\\'))
    return results

def process_output(data, master_fd):
    """Check output for terminal queries and send responses."""
    for pattern, response in TERMINAL_RESPONSES.items():
        if pattern in data:
            os.write(master_fd, response)

    for _, _, response in handle_decrqm(data):
        if response:
            os.write(master_fd, response)
    for _, _, response in handle_dsr(data):
        if response:
            os.write(master_fd, response)
    for _, _, response in handle_kitty_graphics(data):
        if response:
            os.write(master_fd, response)

def set_pty_size(fd, rows, cols):
    winsize = struct.pack('HHHH', rows, cols, 0, 0)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, winsize)

def type_text(master_fd, text, speed=TYPE_SPEED):
    for ch in text:
        os.write(master_fd, ch.encode())
        time.sleep(speed)

def backspace(master_fd, n, speed=TYPE_SPEED):
    for _ in range(n):
        os.write(master_fd, b'\x7f')
        time.sleep(speed)

def main():
    master, slave = pty.openpty()

    set_pty_size(master, 40, 100)
    set_pty_size(slave, 40, 100)

    pid = os.fork()

    if pid == 0:
        os.close(master)
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
        os.dup2(slave, 0)
        os.dup2(slave, 1)
        os.dup2(slave, 2)
        if slave > 2:
            os.close(slave)

        os.environ['TERM'] = 'xterm-256color'
        os.execvp('query-json', ['query-json', '--repl', 'cli/test/mock.json'])
    else:
        os.close(slave)

        running = True
        def relay_output():
            while running:
                try:
                    r, _, _ = select.select([master], [], [], 0.1)
                    if r:
                        data = os.read(master, 16384)
                        if data:
                            process_output(data, master)
                            os.write(1, data)
                        else:
                            break
                except OSError:
                    break

        relay = threading.Thread(target=relay_output, daemon=True)
        relay.start()

        time.sleep(3)

        backspace(master, 1)

        type_text(master, 'keys')
        time.sleep(2)

        backspace(master, 4)

        type_text(master, '.second.store')
        time.sleep(2)

        type_text(master, '.books')
        time.sleep(2)

        type_text(master, '[0]')
        time.sleep(2)

        backspace(master, 3)
        time.sleep(1)

        type_text(master, ' | ma')
        time.sleep(2)

        type_text(master, 'p')
        time.sleep(1)

        type_text(master, '(.price * 77)')
        time.sleep(1)

        backspace(master, 17)
        time.sleep(1)

        type_text(master, ' filter(.price > 10)')
        time.sleep(2.5)

        os.write(master, b'\x03')
        time.sleep(1)

        running = False
        try:
            os.waitpid(pid, 0)
        except ChildProcessError:
            pass
        os.close(master)

if __name__ == '__main__':
    main()
