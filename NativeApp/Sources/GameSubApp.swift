import SwiftUI
import StarfoldShared
import StreamKit
import XboxKit

// New native app. StarfoldShared is used as a *library*, never as the app UI.
@main
struct GameSubApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var xbox = AppDependencies(
        streamPlatform: StreamPlatform(
            controllerRouting: .gated,
            pictureCapabilities: PictureCapabilities(
                canFit: false,
                canEnhance: false,
                shouldKeepLastFrame: true,
                isHDRDisplayAvailable: nil
            ),
            overlays: StreamOverlays(statisticsRows: [], controlsHideDelay: nil),
            touchPlatform: nil
        )
    ).makeAppViewModel()

    var body: some Scene {
        WindowGroup {
            GameSubHome(xbox: xbox)
                .preferredColorScheme(.dark)
                .task {
                    await xbox.restore()
                    xbox.setActive(true)
                }
                .onChange(of: scenePhase) { _, next in
                    xbox.setActive(next == .active)
                    if next == .active {
                        xbox.streamViewModel?.enterForeground()
                    } else {
                        xbox.streamViewModel?.enterBackground()
                    }
                }
        }
    }
}

struct GameSubHome: View {
    let xbox: AppViewModel

    @State private var autoConnected = false
    @AppStorage("gamesub.autolink") private var autoLink = true

    private let sky = Color(red: 0.29, green: 0.82, blue: 0.98)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "character.bubble.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(sky)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("GAME SUB")
                                .font(.system(size: 29, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("مترجم ألعاب Xbox — مو تطبيق بث")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 20)

                    switch xbox.sessionState {
                    case .restoring:
                        ProgressView("جارٍ استرجاع اتصال Xbox...")
                            .tint(sky)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    case .signedOut:
                        GameSubSignIn(xbox: xbox)
                    case .signedIn:
                        if let stream = xbox.streamViewModel {
                            GameSubTranslator(stream: stream) {
                                Task { await xbox.endStream() }
                            }
                            .id(ObjectIdentifier(stream))
                        } else if let home = xbox.homeViewModel {
                            consolePanel(home)
                        } else {
                            ProgressView("جارٍ البحث عن Xbox...")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            .background {
                LinearGradient(
                    colors: [Color(red: 0.035, green: 0.060, blue: 0.14),
                             Color(red: 0.015, green: 0.025, blue: 0.055),
                             .black],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func consolePanel(_ home: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let name = xbox.signedInGamertag {
                Label(name, systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline.bold())
            }

            Text("اتصل بالإكس بوكس")
                .font(.title3.bold())
            Text("الاتصال يستقبل إطارات اللعبة لتحليل نصوصها فقط. صورة اللعبة ما راح تظهر بالجوال.")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            Toggle("اتصال تلقائي إذا كان عندك Xbox واحد", isOn: $autoLink)
                .tint(sky)
                .font(.subheadline)

            if home.consoles.isEmpty {
                Text("ما لقينا Xbox مرتبط بالحساب. تأكد من تفعيل Remote Features في الجهاز.")
                    .font(.caption).foregroundStyle(.orange)
                    .padding(.vertical, 10)
            }

            ForEach(home.consoles, id: \.id) { console in
                Button {
                    Task {
                        autoConnected = true
                        await xbox.play(.console(id: console.id, name: console.name))
                    }
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.title2).foregroundStyle(sky)
                        VStack(alignment: .leading) {
                            Text(console.name)
                                .font(.headline)
                            Text("ابدأ قراءة الترجمة بدون عرض اللعبة")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.left")
                            .foregroundStyle(sky)
                    }
                    .padding(16)
                    .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
            }

            Button {
                Task { await home.refreshConsoles() }
            } label: {
                Label("إعادة البحث عن Xbox", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .tint(sky)

            Button("تسجيل خروج من Xbox", role: .destructive) {
                autoConnected = false
                xbox.signOut()
            }
            .font(.caption)

            Text("يحتاج Remote Play اتصالًا فعليًا بالجهاز، ويجب إبقاء GAME SUB مفتوحًا في المقدمة أثناء الترجمة.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(15)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 20))
        .task(id: home.consoles.map(\.id).joined(separator: "|")) {
            guard autoLink, !autoConnected, home.consoles.count == 1,
                  let console = home.consoles.first else { return }
            autoConnected = true
            await xbox.play(.console(id: console.id, name: console.name))
        }
    }
}

private struct GameSubSignIn: View {
    let xbox: AppViewModel
    @State private var signIn: SignInViewModel?

    var body: some View {
        VStack(spacing: 15) {
            Text("ربط حساب Xbox")
                .font(.title3.bold())
            Text("سجّل حساب Microsoft مرة واحدة. بعدها راح تظهر لك أجهزة Xbox المرتبطة به.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let signIn {
                SignInProgressPanel(model: signIn)
            } else {
                ProgressView("جارٍ تجهيز تسجيل الدخول...")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 20))
        .onAppear {
            if signIn == nil { signIn = xbox.makeSignInViewModel() }
        }
    }
}

private struct SignInProgressPanel: View {
    let model: SignInViewModel

    var body: some View {
        VStack(spacing: 13) {
            switch model.step {
            case .preparing:
                ProgressView("جارٍ طلب رمز Microsoft...")
            case .code(let code):
                Text("افتح الرابط التالي وسجّل دخول Xbox:")
                    .font(.subheadline)
                Link(code.address, destination: code.page)
                    .font(.headline)
                Text(code.text)
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .textSelection(.enabled)
                Button {
                    UIPasteboard.general.string = code.text
                } label: {
                    Label("نسخ رمز الربط", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                Text("إذا فتحت صفحة Microsoft على نفس الجوال، ارجع للتطبيق بعد ما توافق.")
                    .font(.caption).foregroundStyle(.secondary)
            case .progress:
                ProgressView("جارٍ تأكيد حساب Xbox...")
            case .failure(let problem):
                Text(problem)
                    .foregroundStyle(.red)
                    .font(.caption)
                Button("إعادة المحاولة") {
                    model.retry()
                }
                .buttonStyle(.bordered)
            }
        }
        .task(id: model.attempt) {
            await model.run()
        }
    }
}
