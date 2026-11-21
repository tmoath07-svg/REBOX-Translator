import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class IntegrationTests(unittest.TestCase):
    def test_source_is_camera_free(self):
        swift = "\n".join(p.read_text() for p in (ROOT/"ios").glob("*.swift"))
        self.assertIn("lastFrameImage()", swift)
        self.assertIn("VNRecognizeTextRequest", swift)
        self.assertNotIn("AVCaptureSession", swift)
        self.assertNotIn("NSCameraUsageDescription", swift)

    def test_dynamic_port(self):
        code = (ROOT/"ios/REBOXCaptionBridge.swift").read_text()
        self.assertIn("on: .any", code)
        self.assertIn("components(separatedBy: \"?\")", code)
        self.assertNotIn(":8080/tv", code)

    def test_lg_metadata(self):
        obj = json.loads((ROOT/"LGReceiver/appinfo.json").read_text())
        self.assertEqual(obj["main"], "index.html")
        self.assertEqual(obj["id"], "com.tmoath07.reboxtranslator.lg")

    def test_star_fold_patch(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = pathlib.Path(tmp)
            a = base/"StarfoldiOS/Features/Stream/StreamView.swift"
            b = base/"Packages/StreamKit/Sources/StreamKit/Rendering/StreamRenderer.swift"
            a.parent.mkdir(parents=True)
            b.parent.mkdir(parents=True)
            a.write_text("            StreamPicture(\n"
                         "                renderer: streamViewModel.renderer,\n"
                         "                isVisible: streamViewModel.hasFirstFrame\n"
                         "            )\n")
            b.write_text("let lastFrameMaximumWidth: CGFloat = 640\n")
            cmd = [sys.executable, str(ROOT/"scripts/integrate_starfold.py"),
                   "--upstream", str(base)]
            subprocess.run(cmd, check=True, capture_output=True)
            subprocess.run(cmd, check=True, capture_output=True)
            self.assertEqual(a.read_text().count("REBOXTranslatorOverlay(renderer:"), 1)
            self.assertIn("CGFloat = 1280", b.read_text())
            for name in ["REBOXTranslatorOverlay.swift","REBOXCaptionBridge.swift","REBOXTVHTML.swift"]:
                self.assertTrue((a.parent/name).is_file())

if __name__ == "__main__":
    unittest.main()
