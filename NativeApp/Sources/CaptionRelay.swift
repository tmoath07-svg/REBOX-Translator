import Combine
import Foundation
import Network
import Darwin

@MainActor
final class CaptionRelay: ObservableObject {
    @Published private(set) var url = "جارٍ تشغيل خادم الترجمة..."
    @Published private(set) var ready = false
    @Published private(set) var connected = false

    private let server = SubtitleHTTPServer()
    private var lastPoll: Date?
    private var monitor: Timer?

    init() {
        server.onReady = { [weak self] port in
            Task { @MainActor in
                guard let self else { return }
                self.ready = true
                self.url = "http://\(LANIP.address()):\(port)/tv"
            }
        }
        server.onPoll = { [weak self] in
            Task { @MainActor in
                self?.lastPoll = Date()
                self?.connected = true
            }
        }
    }

    func start() {
        server.start()
        if monitor == nil {
            monitor = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.connected = self.lastPoll.map { Date().timeIntervalSince($0) < 8 } ?? false
                }
            }
        }
    }

    func send(_ subtitle: String) {
        server.set(subtitle)
    }

    func stop() {
        monitor?.invalidate()
        monitor = nil
        server.stop()
        ready = false
        connected = false
        lastPoll = nil
    }
}

// Keeps NWListener and each connection on its own serial queue; never binds 8080.
private final class SubtitleHTTPServer: @unchecked Sendable {
    var onReady: ((UInt16) -> Void)?
    var onPoll: (() -> Void)?

    private let queue = DispatchQueue(label: "gamesub.caption.http")
    private let lock = NSLock()
    private var listener: NWListener?
    private var caption = ""

    func start() {
        queue.async { [self] in
            guard listener == nil else { return }
            do {
                let server = try NWListener(using: .tcp, on: .any)
                listener = server
                server.stateUpdateHandler = { [weak self] state in
                    if case .ready = state, let port = server.port?.rawValue {
                        self?.onReady?(port)
                    }
                }
                server.newConnectionHandler = { [weak self] connection in
                    self?.handle(connection)
                }
                server.start(queue: queue)
            } catch {
                // On failures the "connected" indicator stays off; never fake success.
            }
        }
    }

    func stop() {
        queue.async { [self] in
            listener?.cancel()
            listener = nil
        }
    }

    func set(_ value: String) {
        lock.lock()
        caption = value
        lock.unlock()
    }

    private func currentCaption() -> String {
        lock.lock()
        defer { lock.unlock() }
        return caption
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) {
            [weak self] data, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }
            let request = String(decoding: data ?? Data(), as: UTF8.self)
            let firstLine = request.components(separatedBy: "\r\n").first ?? ""
            let path = firstLine.split(separator: " ").dropFirst().first
                .map(String.init)?.components(separatedBy: "?").first ?? "/"

            let body: Data
            let status: String
            let type: String
            switch path {
            case "/", "/tv":
                body = Data(TVReceiverPage.html.utf8)
                status = "200 OK"
                type = "text/html; charset=utf-8"
            case "/state":
                body = (try? JSONSerialization.data(withJSONObject: [
                    "subtitle": self.currentCaption()
                ])) ?? Data("{}".utf8)
                status = "200 OK"
                type = "application/json; charset=utf-8"
                self.onPoll?()
            default:
                body = Data("Not Found".utf8)
                status = "404 Not Found"
                type = "text/plain; charset=utf-8"
            }
            let head = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
            var payload = Data(head.utf8)
            payload.append(body)
            connection.send(content: payload, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}

private enum LANIP {
    static func address() -> String {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let first else {
            return "127.0.0.1"
        }
        defer { freeifaddrs(first) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let pointer = cursor {
            let entry = pointer.pointee
            if let ip = entry.ifa_addr,
               ip.pointee.sa_family == UInt8(AF_INET),
               String(cString: entry.ifa_name) == "en0" {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(ip, socklen_t(ip.pointee.sa_len), &host,
                               socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    return String(cString: host)
                }
            }
            cursor = entry.ifa_next
        }
        return "127.0.0.1"
    }
}
