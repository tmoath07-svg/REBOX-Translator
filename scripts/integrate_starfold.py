#!/usr/bin/env python3
"""Patch a fresh, pinned MIT-licensed Starfold checkout at build time.
Never edits the old REBOX repository or asks for a camera.
"""
from pathlib import Path
import argparse, shutil, sys

parser=argparse.ArgumentParser()
parser.add_argument("--upstream", required=True)
parser.add_argument("--source", default=str(Path(__file__).resolve().parents[1]/"ios"))
args=parser.parse_args()
root=Path(args.upstream)
source=Path(args.source)
view=root/"StarfoldiOS/Features/Stream/StreamView.swift"
renderer=root/"Packages/StreamKit/Sources/StreamKit/Rendering/StreamRenderer.swift"
if not view.is_file() or not renderer.is_file():
    sys.exit("Pinned Starfold layout changed. Refusing to create an unverified IPA.")
needle="""            StreamPicture(
                renderer: streamViewModel.renderer,
                isVisible: streamViewModel.hasFirstFrame
            )"""
patched="""            // No visible Remote Play picture in translator-only mode.
            // StreamKit still decodes and stores console video frames for OCR.
            REBOXTranslatorOverlay(renderer: streamViewModel.renderer)"""
code=view.read_text()
if "REBOXTranslatorOverlay(renderer:" not in code:
    if code.count(needle)!=1: sys.exit("StreamPicture injection anchor mismatch")
    view.write_text(code.replace(needle,patched,1))
code=renderer.read_text()
old="let lastFrameMaximumWidth: CGFloat = 640"
new="let lastFrameMaximumWidth: CGFloat = 1280"
if new not in code:
    if code.count(old)!=1: sys.exit("StreamRenderer lastFrame API mismatch")
    renderer.write_text(code.replace(old,new,1))
for name in ["REBOXTranslatorOverlay.swift","REBOXCaptionBridge.swift","REBOXTVHTML.swift"]:
    p=source/name
    if not p.is_file(): sys.exit("Missing source: "+name)
    shutil.copy2(p,view.parent/name)
print("REBOX: installed headless-visible Xbox frame OCR and text-only translator view; source video remains internal")
