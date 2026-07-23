# Selenium Gemini Pro Runner — Design

**Goal:** Generate the remaining visual assets sequentially through the user's Gemini Pro web subscription, with a resumable local Selenium runner that writes only verified PNGs into the existing asset pipeline.

## Decision

Use Selenium 4 attached to a **dedicated Chrome automation profile** launched with remote debugging on `127.0.0.1:9222`. The user's ordinary Chrome profile remains untouched. On first launch the user signs into Gemini Pro once in the automation window; its cookies persist in the dedicated profile for later runs.

The runner processes exactly one pending asset at a time:

1. Reads the next `NN_assetKey.md` from `Tools/asset-pipeline/prompts/gemini_pro/`.
2. Opens a clean Gemini chat, pastes `heroes/approved/fisura.png` when the MD requires a visual reference, and submits the exact prompt.
3. Waits for Gemini's full-size download control; downloads the asset.
4. Verifies a new PNG exists, is decodable, and is at least 100 KB before moving it to `dropbox/<assetKey>.png`.
5. Writes an atomic checkpoint and marks the prompt MD `hecho` only after the file verification.

`process_dropbox.py` stays a separate explicit phase: it removes the white background to RGBA, exports atlas sizes, and updates the manifest. The Selenium runner never edits the Xcode project or manifest.

## Safety and failure behavior

- The runner does not overwrite an existing `dropbox/<assetKey>.png`.
- It stops immediately on CAPTCHA, Gemini quota/rate-limit copy, missing selector, unexpected modal, failed download, or timeout.
- It leaves the current asset `pendiente` and records the reason in `state/selenium-run.json`.
- It has `--limit`, `--only`, `--dry-run`, `--pause`, `--resume`, `--headless` (default off), and `--process` flags.
- Every browser interaction is bounded by explicit Selenium waits; no blind sleeps beyond a small download-settle delay.

## Browser lifecycle

`scripts/launch_gemini_chrome.py` launches Google Chrome with:

```text
--remote-debugging-port=9222
--user-data-dir=Tools/asset-pipeline/.chrome-profile
--no-first-run
--no-default-browser-check
https://gemini.google.com/app
```

The profile directory is gitignored. Selenium attaches through `debuggerAddress=127.0.0.1:9222`, using Selenium Manager to obtain a matching ChromeDriver automatically. This avoids depending on the Claude-in-Chrome MCP session and avoids clobbering the user's normal Chrome process.

## Files

| File | Responsibility |
|---|---|
| `Tools/asset-pipeline/scripts/gemini_selenium_runner.py` | Queue, browser automation, downloads, checkpoints, CLI. |
| `Tools/asset-pipeline/scripts/launch_gemini_chrome.py` | Idempotently launches or opens the dedicated debug Chrome. |
| `Tools/asset-pipeline/tests/test_gemini_selenium_runner.py` | Pure queue/checkpoint/download verification tests; no Gemini account required. |
| `Tools/asset-pipeline/requirements.txt` | Adds pinned Selenium dependency. |
| `.gitignore` | Ignores `.chrome-profile/`, `state/selenium-run.json`, and transient downloads. |
| `Tools/asset-pipeline/README.md` | Documents first login, smoke test, sequential run, resume, stop, and processing. |

## Acceptance checks

1. Python tests prove pending assets are sequenced correctly, completed assets are skipped, an undersized/invalid file is rejected, and failed assets are not marked done.
2. `--dry-run --limit 3` lists the same next three MDs as the index.
3. First real smoke run (`--only junior_programmer`) opens the dedicated browser, generates one PNG, verifies it, and writes it to `dropbox/` without updating the manifest.
4. `process_dropbox.py` turns the PNG into a transparent RGBA asset, atlas entries, and one manifest entry.
5. An interrupted run resumes at the next pending MD without duplicating a download.
