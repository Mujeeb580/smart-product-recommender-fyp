"""Download the official JDK and Android command-line tools used for APK builds."""

from pathlib import Path

import requests


DOWNLOADS = (
    (
        "https://download.visualstudio.microsoft.com/download/pr/"
        "8fdc33a5-2cf8-4e3a-82a8-abe718da0aea/"
        "f09364512aaaabfd27bcd1014f3f66a6/"
        "microsoft-jdk-17.0.19-windows-x64.zip",
        "microsoft-jdk17.zip",
    ),
    (
        "https://dl.google.com/android/repository/"
        "commandlinetools-win-14742923_latest.zip",
        "android-commandlinetools.zip",
    ),
)


def main() -> None:
    target_dir = Path(r"E:\FYP\.android-toolchain\downloads")
    target_dir.mkdir(parents=True, exist_ok=True)

    for url, filename in DOWNLOADS:
        target = target_dir / filename
        if target.exists() and target.stat().st_size > 1_000_000:
            print(f"Already downloaded: {target} ({target.stat().st_size:,} bytes)")
            continue

        partial = target.with_suffix(target.suffix + ".part")
        downloaded = partial.stat().st_size if partial.exists() else 0
        headers = {"Accept-Encoding": "identity"}
        if downloaded:
            headers["Range"] = f"bytes={downloaded}-"
        print(f"Downloading {filename} from byte {downloaded:,} ...", flush=True)
        with requests.get(
            url, headers=headers, stream=True, timeout=(30, 300)
        ) as response:
            response.raise_for_status()
            resumed = downloaded > 0 and response.status_code == 206
            mode = "ab" if resumed else "wb"
            if not resumed:
                downloaded = 0
            next_report = downloaded + 10 * 1024 * 1024
            with partial.open(mode) as output:
                for chunk in response.iter_content(chunk_size=1024 * 1024):
                    if not chunk:
                        continue
                    output.write(chunk)
                    output.flush()
                    downloaded += len(chunk)
                    if downloaded >= next_report:
                        print(f"  {downloaded / 1024 / 1024:.1f} MiB", flush=True)
                        next_report = downloaded + 10 * 1024 * 1024
        partial.replace(target)
        print(f"Downloaded: {target} ({target.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
