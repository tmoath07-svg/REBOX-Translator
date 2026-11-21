# REBOX Translator — Xbox subtitle translation without a camera

A **separate, free, open-source project**. It is NOT an update to the old REBOX repository.

## Architecture

1. GitHub Actions downloads the pinned, MIT-licensed [Starfold](https://github.com/JarvanSun/Starfold) Xbox Remote Play client at a specific commit.
2. Our build-time Python script reuses Starfold's Xbox authentication and internal Remote Play decoder, **replaces the visible game video with a subtitle-only screen**, and does not show a virtual gamepad.
3. Apple Vision OCR reads frames returned by `StreamRenderer.lastFrameImage()`. No iPhone camera is used.
4. Apple Translation translates English→Arabic on-device (download the language models when prompted). Other selectable source/target pairs include German→English.
5. A local TCP HTTP server selects a free port automatically (avoids NWError 48) and exposes `/tv` and `/state` endpoints on the user's home Wi-Fi.
6. Open the `/tv` URL in LG webOS's browser. An optional separate LG webOS IPK receiver can be built from `LGReceiver`.

## Device workflow

1. Install a successfully built and signed unsigned IPA from the **Build REBOX Translator iOS** GitHub workflow.
2. Sign in with Microsoft and select your Xbox for a Remote Play session. The video is received internally for OCR **but is not shown on the iPhone**; an active Xbox stream is still necessary.
3. The **REBOX ترجمة** subtitle-only screen automatically starts OCR when a stream arrives. Pick English→Arabic and approve Apple's free language-model download if requested.
4. Copy the local TV URL and open it in your LG browser (same Wi-Fi).
5. Adjust the proportional OCR rectangle to the lower subtitle area. The phone shows recognized/translated text only; the LG browser receives translated text. The app must remain open in the foreground.

**No camera, no copy/paste, no paid API, no in-app purchase or subscription** in the application source. First-time Apple language downloads require iOS support, storage, internet and permission. Microsoft's Xbox connection remains necessary.

## HDMI compatibility

The built-in LG browser *may not* support embedded `ext://hdmi:N` alongside the page. Simply switching to Xbox HDMI closes the browser's page in many LG models. The LG webOS IPK requests a transparent overlay but whether it actually overlays live hardware HDMI depends on model/firmware/permissions. **Never treat successful compilation as proof of full HDMI overlay.**

The native Xbox-to-LG text transport does not depend on HDMI capture: the iOS app reads frames from the existing native Remote Play stream, not the HDMI cable.

## Build from GitHub (no computer)

- `.github/workflows/check.yml`: unit/static tests.
- `.github/workflows/build-ios.yml`: builds an **unsigned** `REBOX-Translator-unsigned.ipa` using Xcode 27 on a GitHub macOS runner.
- `.github/workflows/build-lg.yml`: packages an experimental `.ipk` for compatible LG webOS TVs.
- Signing an iOS IPA needs the user's own allowed signing arrangement (such as ESign or SideStore). The workflow does not include certificates.

Pinned Starfold commit: `1d30a4c08042f78df5ce70750922374ef1612a1f` (MIT). See [third-party notices](THIRD_PARTY_NOTICES.md) and [hardware test plan](docs/TEST_PLAN.md).

## Test status

The Python integration script and static tests are included and should run on every push. **Native IPA compilation and gameplay translation must be verified in GitHub Actions and on actual Xbox/LG hardware.** If the build fails, the workflow logs are the source of truth and will be repaired; no pretend-success IPA.

Original code is under MIT. REBOX Translator is independent and not endorsed by Apple, LG, Microsoft or Starfold contributors.
