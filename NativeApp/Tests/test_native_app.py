import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "Sources"

class NativeGameSubTests(unittest.TestCase):
    def test_own_app_target_not_rebranded_star_fold(self):
        app = (SRC / "GameSubApp.swift").read_text()
        config = (ROOT / "project.yml").read_text()
        self.assertIn("@main", app)
        self.assertIn("struct GameSubApp: App", app)
        self.assertIn("GameSubHome", app)
        self.assertNotIn("RootView()", app)
        self.assertIn("com.tmoath07.gamesub", config)
        self.assertNotIn("StarfoldiOS/Features", config)

    def test_internal_xbox_frames_only(self):
        translator = (SRC / "GameSubTranslator.swift").read_text()
        self.assertIn("lastFrameImage()", translator)
        self.assertIn("VNRecognizeTextRequest()", translator)
        self.assertIn("session.translate(text)", translator)
        self.assertIn("relay.send(value)", translator)
        self.assertNotIn("AVCaptureSession", translator)
        self.assertNotIn("StreamPicture(", translator)
        self.assertNotIn("VideoPlayer(", translator)

    def test_port_and_lg_polling(self):
        server = (SRC / "CaptionRelay.swift").read_text()
        html = (SRC / "TVReceiverPage.swift").read_text()
        self.assertIn("on: .any", server)
        self.assertIn('case "/state"', server)
        self.assertIn('components(separatedBy: "?")', server)
        self.assertIn("/state?t=", html)
        self.assertIn("service/webos-external", html)
        self.assertIn("تجريبي", html)

    def test_no_camera_permission(self):
        text = "\n".join(p.read_text() for p in SRC.glob("*.swift"))
        metadata = (ROOT / "project.yml").read_text()
        self.assertNotIn("NSCameraUsageDescription", metadata)
        self.assertNotIn("AVCapture", text)
        self.assertNotIn("UIImagePicker", text)

if __name__ == "__main__":
    unittest.main()
