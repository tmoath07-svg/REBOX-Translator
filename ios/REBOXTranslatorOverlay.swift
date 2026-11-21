import SwiftUI
import StreamKit
@preconcurrency import Translation
import Vision
import CoreGraphics
import UIKit

// Uses decoded Xbox Remote Play frames only: no camera, capture hardware or paid API.
struct REBOXTranslatorOverlay: View {
    let renderer: StreamRenderer?
    @StateObject private var bridge = REBOXCaptionBridge()
    @State private var enabled = false
    @State private var settingsOpen = false
    @State private var editingArea = false
    @State private var crop = CGRect(x: 0.08, y: 0.76, width: 0.84, height: 0.20)
    @State private var source = "en"
    @State private var destination = "ar"
    @State private var config: TranslationSession.Configuration?
    @State private var pending = ""
    @State private var prepareLanguages = false
    @State private var previous = ""
    @State private var consecutive = 0
    @State private var lastRecognized = ""
    @State private var cache: [String: String] = [:]
    @State private var message = "اربط Xbox ثم فعّل قراءة النصوص."
    private let cyan = Color(red: 0.34, green: 0.86, blue: 0.99)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if editingArea && enabled { cropView }
            VStack(alignment: .trailing, spacing: 8) {
                Button { settingsOpen.toggle() } label: {
                    Label("REBOX ترجمة", systemImage: "character.bubble")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(.black.opacity(0.92), in: Capsule())
                        .overlay(Capsule().stroke(cyan))
                }
                .tint(cyan)
                if settingsOpen { settings }
            }
            .padding(.top, 28).padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .task(id: enabled) {
            guard enabled else { return }
            while !Task.isCancelled {
                if let image = renderer?.lastFrameImage() {
                    recognize(image)
                } else {
                    message = "ما وصلنا بث فيديو من Xbox للحين."
                }
                try? await Task.sleep(for: .milliseconds(1000))
            }
        }
        .translationTask(config) { session in
            do {
                if prepareLanguages {
                    try await session.prepareTranslation()
                    prepareLanguages = false
                    message = "تم تجهيز اللغات أو الموافقة على تنزيلها."
                    return
                }
                let text = pending
                guard !text.isEmpty else { return }
                let response = try await session.translate(text)
                guard text == pending else { return }
                let translated = response.targetText
                cache[cacheKey(text)] = translated
                if cache.count > 100 {
                    cache.removeAll()
                    cache[cacheKey(text)] = translated
                }
                bridge.setSubtitle(translated)
                message = "تم إرسال الترجمة للتلفزيون."
            } catch {
                prepareLanguages = false
                message = "تعذرت الترجمة: \(error.localizedDescription)"
            }
        }
        .onChange(of: source) { _, _ in config = nil; cache.removeAll() }
        .onChange(of: destination) { _, _ in config = nil; cache.removeAll() }
        .onAppear { bridge.start() }
        .onDisappear { bridge.stop() }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ترجمة ألعاب Xbox بدون كاميرا")
                .font(.headline).foregroundStyle(cyan)
            Toggle("الترجمة التلقائية", isOn: $enabled)
                .tint(.green)
            Text("قراءة مباشرة من إطارات Remote Play داخل التطبيق.")
                .font(.caption).foregroundStyle(.gray)
            HStack {
                Picker("من", selection: $source) {
                    Text("English").tag("en")
                    Text("German").tag("de")
                    Text("French").tag("fr")
                    Text("Spanish").tag("es")
                }.pickerStyle(.menu)
                Spacer()
                Image(systemName: "arrow.left")
                Picker("إلى", selection: $destination) {
                    Text("العربية").tag("ar")
                    Text("English").tag("en")
                    Text("Deutsch").tag("de")
                    Text("Français").tag("fr")
                }.pickerStyle(.menu)
            }
            Button {
                prepareLanguages = true
                startTranslation()
            } label: {
                Label("تنزيل لغات Apple مجانًا", systemImage: "arrow.down.circle")
            }
            .tint(cyan)
            Divider()
            Toggle("تحديد مربع النص الأزرق", isOn: $editingArea).tint(cyan)
            if editingArea {
                Text("الموضع العمودي")
                Slider(value: Binding(get: { Double(crop.origin.y) }, set: {
                    crop.origin.y = min(CGFloat($0), 1 - crop.height)
                }), in: 0...0.9)
                Text("عرض مربع النص")
                Slider(value: Binding(get: { Double(crop.width) }, set: {
                    crop.size.width = CGFloat($0)
                    crop.origin.x = min(crop.origin.x, 1 - crop.width)
                }), in: 0.2...1)
                Text("ارتفاع مربع النص")
                Slider(value: Binding(get: { Double(crop.height) }, set: {
                    crop.size.height = CGFloat($0)
                    crop.origin.y = min(crop.origin.y, 1 - crop.height)
                }), in: 0.07...0.5)
            }
            HStack {
                Image(systemName: "circle.fill")
                    .foregroundStyle(bridge.isReceiverConnected ? Color.green : Color.orange)
                    .font(.system(size: 9))
                Text(bridge.isReceiverConnected ? "LG متصل" : "LG غير متصل")
                    .font(.caption)
                Spacer()
                Button("نسخ رابط LG") {
                    guard bridge.isReady else { return }
                    UIPasteboard.general.string = bridge.tvURL
                    message = "افتح الرابط في متصفح LG."
                }
                .disabled(!bridge.isReady).font(.caption)
            }
            Text(bridge.tvURL)
                .font(.system(size: 10, design: .monospaced))
                .textSelection(.enabled)
            Text(message)
                .font(.caption).fixedSize(horizontal: false, vertical: true)
            if !lastRecognized.isEmpty {
                Text("OCR: " + lastRecognized).lineLimit(2).font(.caption2).foregroundStyle(cyan)
            }
        }
        .foregroundStyle(.white)
        .padding(13).frame(width: 325)
        .background(.black.opacity(0.95), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(cyan.opacity(0.6)))
    }

    private var cropView: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 8)
                .fill(cyan.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(cyan, lineWidth: 3))
                .frame(width: geo.size.width * crop.width, height: geo.size.height * crop.height)
                .position(x: geo.size.width * crop.midX, y: geo.size.height * crop.midY)
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let x = value.location.x / max(1, geo.size.width)
                    let y = value.location.y / max(1, geo.size.height)
                    crop.origin.x = min(max(0, x - crop.width/2), 1 - crop.width)
                    crop.origin.y = min(max(0, y - crop.height/2), 1 - crop.height)
                })
        }
    }

    private func recognize(_ image: CGImage) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [[
            "en": "en-US", "de": "de-DE",
            "fr": "fr-FR", "es": "es-ES"
        ][source] ?? "en-US"]
        request.regionOfInterest = CGRect(
            x: crop.minX, y: 1 - crop.maxY, width: crop.width, height: crop.height
        )
        do {
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            let text = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 4, text.count < 300 else {
                previous = ""
                consecutive = 0
                return
            }
            if text == previous { consecutive += 1 }
            else { previous = text; consecutive = 1 }
            guard consecutive >= 2, text != lastRecognized else { return }
            lastRecognized = text
            if let stored = cache[cacheKey(text)] {
                bridge.setSubtitle(stored)
                message = "ترجمة محفوظة؛ تم الإرسال."
            } else {
                pending = text
                prepareLanguages = false
                startTranslation()
            }
        } catch {
            message = "Vision OCR: \(error.localizedDescription)"
        }
    }

    private func cacheKey(_ text: String) -> String {
        "\(source):\(destination):\(text)"
    }

    private func startTranslation() {
        guard source != destination else {
            message = "حدد لغتين مختلفتين."
            return
        }
        let src = Locale.Language(identifier: source)
        let dst = Locale.Language(identifier: destination)
        if let current = config, current.source == src && current.target == dst {
            config?.invalidate()
        } else {
            config = TranslationSession.Configuration(source: src, target: dst)
        }
    }
}
