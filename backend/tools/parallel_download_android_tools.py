"""Resume Google Android command-line tools with parallel HTTP byte ranges."""

from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import re
import shutil
import threading

import requests


URL = (
    "https://dl.google.com/android/repository/"
    "commandlinetools-win-14742923_latest.zip"
)
DOWNLOAD_DIR = Path(r"E:\FYP\.android-toolchain\downloads")
PARTIAL = DOWNLOAD_DIR / "android-commandlinetools.zip.part"
TARGET = DOWNLOAD_DIR / "android-commandlinetools.zip"
WORKERS = 8
print_lock = threading.Lock()


def remote_size() -> int:
    headers = {"Accept-Encoding": "identity", "Range": "bytes=0-0"}
    with requests.get(URL, headers=headers, stream=True, timeout=(30, 120)) as response:
        response.raise_for_status()
        match = re.fullmatch(r"bytes 0-0/(\d+)", response.headers.get("Content-Range", ""))
        if response.status_code != 206 or not match:
            raise RuntimeError("Google download endpoint did not honor byte ranges")
        return int(match.group(1))


def download_segment(index: int, start: int, end: int) -> Path:
    path = DOWNLOAD_DIR / f"android-commandlinetools.segment-{index:02d}"
    existing = path.stat().st_size if path.exists() else 0
    expected = end - start + 1
    if existing > expected:
        raise RuntimeError(f"Segment {index} is larger than expected")
    if existing == expected:
        return path

    range_start = start + existing
    headers = {
        "Accept-Encoding": "identity",
        "Range": f"bytes={range_start}-{end}",
    }
    with requests.get(URL, headers=headers, stream=True, timeout=(30, 300)) as response:
        response.raise_for_status()
        if response.status_code != 206:
            raise RuntimeError(f"Segment {index} did not receive HTTP 206")
        mode = "ab" if existing else "wb"
        downloaded = existing
        next_report = downloaded + 5 * 1024 * 1024
        with path.open(mode) as output:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if not chunk:
                    continue
                output.write(chunk)
                output.flush()
                downloaded += len(chunk)
                if downloaded >= next_report:
                    with print_lock:
                        print(
                            f"Segment {index}: {downloaded / 1024 / 1024:.1f} MiB",
                            flush=True,
                        )
                    next_report = downloaded + 5 * 1024 * 1024

    if path.stat().st_size != expected:
        raise RuntimeError(
            f"Segment {index} has {path.stat().st_size} bytes; expected {expected}"
        )
    return path


def main() -> None:
    DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
    total = remote_size()
    prefix = PARTIAL.stat().st_size if PARTIAL.exists() else 0
    if prefix > total:
        raise RuntimeError("Existing partial archive is larger than the remote file")
    if prefix == total:
        PARTIAL.replace(TARGET)
        print(f"Download complete: {TARGET} ({total:,} bytes)")
        return

    remaining = total - prefix
    worker_count = min(WORKERS, remaining)
    segment_size = (remaining + worker_count - 1) // worker_count
    ranges = []
    for index in range(worker_count):
        start = prefix + index * segment_size
        end = min(total - 1, start + segment_size - 1)
        if start <= end:
            ranges.append((index, start, end))

    print(
        f"Resuming {total:,}-byte archive at {prefix:,} bytes "
        f"with {len(ranges)} streams",
        flush=True,
    )
    completed: dict[int, Path] = {}
    with ThreadPoolExecutor(max_workers=len(ranges)) as executor:
        futures = {
            executor.submit(download_segment, index, start, end): index
            for index, start, end in ranges
        }
        for future in as_completed(futures):
            index = futures[future]
            completed[index] = future.result()
            print(f"Segment {index} complete", flush=True)

    with PARTIAL.open("ab") as output:
        for index in sorted(completed):
            segment = completed[index]
            with segment.open("rb") as source:
                shutil.copyfileobj(source, output, length=1024 * 1024)
            segment.unlink()

    if PARTIAL.stat().st_size != total:
        raise RuntimeError("Combined archive size does not match the remote file")
    PARTIAL.replace(TARGET)
    print(f"Download complete: {TARGET} ({total:,} bytes)")


if __name__ == "__main__":
    main()
