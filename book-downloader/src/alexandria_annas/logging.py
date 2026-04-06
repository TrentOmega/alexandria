"""Small logging helpers."""

from __future__ import annotations

import sys
import time


def log(message: str) -> None:
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}", file=sys.stderr)

