import SwiftUI
import StarfoldShared
import StreamKit
import Translation
import Vision
import CoreGraphics
import UIKit

// Native translator-only UI. Xbox images are never drawn onto any iPhone view.
struct GameSubTranslator: View {
    let stream: StreamViewModel
    let onStop: () -> Void

    @StateObject private var relay = CaptionRelay()
    @State private var active = true
    @State private var english = ""
    @State private var arabic = ""
    @State private var diagnostic = "بانتظار إطارات Xbox..."
    @State private var previousRead = ""
    @State private var consecutiveReads = 0

    @State private var selectedSource = "en"
    @State private var selectedTarget = "ar"
    @State private var modelConfig: TranslationSession.Configuration?
    @State private var requested = ""
    @State private var prepareModels = false
    @State private var cache: [String: String] = [:]

    @State private var showOptions = false
    @State private var crop = CGRect(x: 0.07, y: 0.72, width: 0.86, height: 0.22)

    private let cyan = Color(red: 0.34, green: 0.84, blue: 0.97)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(stream.hasFirstFrame ? .green : .orange)
                Text(stream.hasFirstFrame
                     ? "Xbox: تم استقبال إطارات الفيديو داخليًا"
                     : "Xbox: جارٍ الاتصال واستقبال البث")
                    .font(.subheadline.bold())
                Spacer()
                Button("إنهاء", role: .destructive, action: onStop)
                    .font(.subheadline)
            }

            VStack(spacing: 14) {
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(cyan)
                Text(arabic.isEmpty ? "بانتظار ظهور كلام في اللعبة..." : arabic)
                    .font(.system(size: arabic.isEmpty ? 19 : 27, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 104)
                    .padding(.horizontal, 10)
                Text("بدون عرض صورة Xbox على الجوال")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 22))

            Toggle("قراءة نصوص اللعبة تلقائيًا", isOn: $active)
                .tint(.cyan)
                .font(.subheadline.bold())

            HStack {
                Image(systemName: "tv")
                    .foregroundStyle(cyan)
                Text(relay.connected ? "متصفح LG متصل" : "لم يتصل متصفح LG بعد")
                    .font(.subheadline)
                    .foregroundStyle(relay.connected ? .green : .orange)
            }

            Text(relay.url)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(.white)

            Button {
                guard relay.ready else { return }
                UIPasteboard.general.string = relay.url
                diagnostic = "تم نسخ الرابط. افتحه بمتصفح LG على نفس شبكة Wi-Fi."
            } label: {
                Label("نسخ رابط التلفزيون", systemImage: "doc.on.doc")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(cyan)
            .foregroundStyle(.black)
            .disabled(!relay.ready)

            DisclosureGroup(isExpanded: $showOptions) {
                options
                    .padding(.top, 10)
            } label: {
                Label("اللغات ومنطقة الكلام", systemImage: "slider.horizontal.3")
                    .font(.headline)
            }
            .tint(cyan)

            if !english.isEmpty {
                Text("النص المكتشف: " + english)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(diagnostic)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 22))
        .onAppear {
            relay.start()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            relay.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .task(id: active) {
            guard active else { return }
            while !Task.isCancelled {
                if let image = stream.renderer?.lastFrameImage() {
                    recognize(image)
                } else {
                    diagnostic = "الاتصال مستمر لكن ما وصلت صورة اللعبة بعد."
                }
                try? await Task.sleep(for: .milliseconds(1050))
            }
        }
        .translationTask(modelConfig) { session in
            do {
                if prepareModels {
                    try await session.prepareTranslation()
                    prepareModels = false
                    diagnostic = "تم تجهيز اللغات أو قبول تنزيلها من Apple."
                    return
                }

                let text = requested
                guard !text.isEmpty else { return }
                let result = try await session.translate(text)
                guard requested == text else { return }
                let value = result.targetText
                let key = cacheKey(text)
                cache[key] = value
                if cache.count > 120 {
                    cache.removeAll()
                    cache[key] = value
                }
                arabic = value
                relay.send(value)
                diagnostic = "الترجمة جاهزة وأُرسلت إلى رابط LG."
            } catch {
                prepareModels = false
                diagnostic = "تعذر استخدام الترجمة: \(error.localizedDescription)"
            }
        }
        .onChange(of: selectedSource) { _, _ in resetLanguages() }
        .onChange(of: selectedTarget) { _, _ in resetLanguages() }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Picker("من", selection: $selectedSource) {
                    Text("English").tag("en")
                    Text("Deutsch").tag("de")
                    Text("Français").tag("fr")
                    Text("Español").tag("es")
                }
                .pickerStyle(.menu)
                Spacer()
                Image(systemName: "arrow.left")
                Picker("إلى", selection: $selectedTarget) {
                    Text("العربية").tag("ar")
                    Text("English").tag("en")
                    Text("Deutsch").tag("de")
                    Text("Français").tag("fr")
                }
                .pickerStyle(.menu)
            }

            Button {
                prepareModels = true
                runTranslationSession()
            } label: {
                Label("تجهيز أو تنزيل لغات الترجمة مجانًا", systemImage: "arrow.down.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)

            Text("حدد المنطقة اللي يظهر فيها النص في اللعبة. المربع هنا تخطيط نسبي، وليس صورة من البث.")
                .font(.caption).foregroundStyle(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.06, green: 0.10, blue: 0.18))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.5)))
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(cyan, lineWidth: 3)
                        .background(cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        .frame(width: geometry.size.width * crop.width,
                               height: geometry.size.height * crop.height)
                        .position(x: geometry.size.width * crop.midX,
                                  y: geometry.size.height * crop.midY)
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            let px = value.location.x / max(1, geometry.size.width)
                            let py = value.location.y / max(1, geometry.size.height)
                            crop.origin.x = min(max(0, px - crop.width / 2), 1 - crop.width)
                            crop.origin.y = min(max(0, py - crop.height / 2), 1 - crop.height)
                        })
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)

            HStack {
                Button("أسفل") { crop = CGRect(x: 0.07, y: 0.72, width: 0.86, height: 0.22) }
                Button("وسط") { crop = CGRect(x: 0.07, y: 0.41, width: 0.86, height: 0.2) }
                Button("أعلى") { crop = CGRect(x: 0.07, y: 0.07, width: 0.86, height: 0.22) }
            }
            .buttonStyle(.bordered)
            .font(.caption)

            Text("عرض المنطقة")
                .font(.caption)
            Slider(value: Binding(
                get: { Double(crop.width) },
                set: { crop.size.width = CGFloat($0); crop.origin.x = min(crop.origin.x, 1-crop.width) }
            ), in: 0.2...1)
            Text("ارتفاع المنطقة")
                .font(.caption)
            Slider(value: Binding(
                get: { Double(crop.height) },
                set: { crop.size.height = CGFloat($0); crop.origin.y = min(crop.origin.y, 1-crop.height) }
            ), in: 0.08...0.6)

            Text("إظهار العربية فوق HDMI الأصلي في LG يعتمد على دعم التلفزيون؛ رابط المتصفح وحده لا يضمن ذلك.")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 6)
    }

    private func recognize(_ frame: CGImage) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [[
            "en": "en-US", "de": "de-DE",
            "fr": "fr-FR", "es": "es-ES"
        ][selectedSource] ?? "en-US"]
        request.regionOfInterest = CGRect(
            x: crop.minX, y: max(0, 1 - crop.maxY),
            width: crop.width, height: crop.height
        )

        do {
            try VNImageRequestHandler(cgImage: frame, options: [:]).perform([request])
            let text = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard text.count >= 4, text.count < 280 else {
                consecutiveReads = 0
                previousRead = ""
                return
            }

            if text == previousRead { consecutiveReads += 1 }
            else { previousRead = text; consecutiveReads = 1 }

            guard consecutiveReads >= 2, text != english else { return }
            english = text
            let key = cacheKey(text)
            if let saved = cache[key] {
                arabic = saved
                relay.send(saved)
                diagnostic = "تم إرسال ترجمة محفوظة."
            } else {
                requested = text
                prepareModels = false
                runTranslationSession()
            }
        } catch {
            diagnostic = "خطأ في قراءة النص: \(error.localizedDescription)"
        }
    }

    private func cacheKey(_ text: String) -> String {
        "\(selectedSource):\(selectedTarget):\(text)"
    }

    private func resetLanguages() {
        modelConfig = nil
        cache.removeAll()
        english = ""
        previousRead = ""
        consecutiveReads = 0
    }

    private func runTranslationSession() {
        guard selectedSource != selectedTarget else {
            diagnostic = "اختر لغتين مختلفتين."
            return
        }
        let src = Locale.Language(identifier: selectedSource)
        let dst = Locale.Language(identifier: selectedTarget)

        if let current = modelConfig, current.source == src, current.target == dst {
            modelConfig?.invalidate()
        } else {
            modelConfig = TranslationSession.Configuration(source: src, target: dst)
        }
    }
}
