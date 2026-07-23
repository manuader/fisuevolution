# Selenium Gemini Pro Runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate visual assets sequentially through Gemini Pro web subscription with a resumable Selenium runner.

**Architecture:** A launcher owns a dedicated Chrome debug profile on localhost. The runner attaches to that browser, submits one prompt MD at a time, confirms the downloaded PNG is valid, then records its checkpoint. `process_dropbox.py` remains the only code that creates RGBA assets, atlases, and manifest entries.

**Tech Stack:** Python 3.12, Selenium 4, Chrome 150, PIL, existing rembg pipeline, unittest.

## Global Constraints

- Do not attach Selenium to the user’s day-to-day Chrome profile.
- Do not mark an MD `hecho` unless a decodable PNG larger than 100 KB reached `dropbox/<assetKey>.png`.
- Do not change the Xcode manifest from the browser runner.
- Use bounded waits, not indefinite sleeps.
- Stop without marking an asset done on CAPTCHA, quota, unexpected modal, selector mismatch, download failure, or timeout.

---

### Task 1: Tested queue and download verification core

**Files:**
- Create: `Tools/asset-pipeline/tests/test_gemini_selenium_runner.py`
- Create: `Tools/asset-pipeline/scripts/gemini_selenium_runner.py`

**Interfaces:** `Asset`, `pending_assets()`, `verify_png()`, `RunCheckpoint`.

- [ ] Write tests for pending asset order, already-done MDs, manifest entries, invalid PNGs, and undersized files.
- [ ] Run the test file; expected initial result: import failure for `gemini_selenium_runner`.
- [ ] Implement only parsing, queue selection, PNG validation, and atomic JSON checkpoint methods.
- [ ] Re-run the test file; expected result: all tests pass.
- [ ] Commit: `feat(f3): add tested Selenium asset queue core`.

### Task 2: Isolated Chrome lifecycle

**Files:**
- Create: `Tools/asset-pipeline/scripts/launch_gemini_chrome.py`
- Modify: `Tools/asset-pipeline/requirements.txt`
- Modify: `.gitignore`
- Modify: test file from Task 1.

**Interfaces:** `debug_url(port=9222)`, `chrome_command(profile, port)`, `ensure_debug_chrome(port=9222)`.

- [ ] Write tests that assert `http://127.0.0.1:9222/json/version`, `--remote-debugging-port=9222`, and the dedicated `.chrome-profile` path.
- [ ] Run tests; expected initial result: missing lifecycle symbols.
- [ ] Add `selenium==4.39.0`, ignore `.chrome-profile/` and `state/selenium-run.json`, then implement an idempotent launcher that probes the debug endpoint before opening Chrome at Gemini.
- [ ] Run the test file; expected result: all tests pass.
- [ ] Run `launch_gemini_chrome.py`, then `curl -fsS http://127.0.0.1:9222/json/version`; user logs into Gemini once in the dedicated window if required.
- [ ] Commit: `feat(f3): launch isolated Chrome profile for Gemini Selenium`.

### Task 3: One real browser generation

**Files:**
- Modify: `Tools/asset-pipeline/scripts/gemini_selenium_runner.py`
- Modify: `Tools/asset-pipeline/README.md`
- Modify: `Tools/asset-pipeline/tests/test_gemini_selenium_runner.py`

**Interfaces:** `GeminiBrowser.generate(asset, reference, downloads) -> Path`, `AssetRunner.run(asset)`.

- [ ] Write a fake-browser test proving a failed/invalid download stays `pendiente` and records failure.
- [ ] Run tests; expected initial result: missing `AssetRunner`.
- [ ] Add Selenium interactions: new chat, reference upload where needed, prompt submission, UI quota/CAPTCHA detection, full-size download, and polling for a new verified PNG.
- [ ] Re-run tests; expected result: all tests pass.
- [ ] Run a real smoke test for exactly `junior_programmer`; expected result: valid `dropbox/junior_programmer.png`, MD becomes `hecho`, manifest untouched.
- [ ] Commit: `feat(f3): automate one Gemini Pro asset through Selenium`.

### Task 4: Resume and handoff

**Files:**
- Modify: `Tools/asset-pipeline/scripts/gemini_selenium_runner.py`
- Modify: `Tools/asset-pipeline/README.md`
- Modify: `tasks.md`
- Modify: test file.

**Interfaces:** CLI flags `--limit`, `--only`, `--dry-run`, `--pause`, `--resume`, `--process`; checkpoint `state/selenium-run.json`.

- [ ] Add a test proving a verified checkpoint advances to the next asset without duplication.
- [ ] Confirm test fails, then implement minimal resume behavior and confirm all tests pass.
- [ ] Run a real `--dry-run --limit 5`; expected output: next five asset keys in evolution order.
- [ ] Document first login, stop, resume, and the explicit `process_dropbox.py` RGBA/atlas handoff.
- [ ] Commit: `feat(f3): add resumable sequential Gemini Selenium runner`.
