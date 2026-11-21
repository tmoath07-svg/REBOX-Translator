import Combine
import Foundation
import Network
import UIKit
import Darwin

@MainActor
final class REBOXCaptionBridge: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var isReceiverConnected = false
    @Published private(set) var tvURL = "جارٍ تشغيل الخادم..."

    private let server = REBOXHTTPServer()
    private var lastPoll: Date?
    private var monitor: Timer?

    init() {
        server.onReady = { [weak self] port in
            Task { @MainActor in
                self?.isReady = true
                self?.tvURL = "http://\(REBOXLAN.ipv4()):\(port)/tv"
            }
        }
        server.onPoll = { [weak self] in
            Task { @MainActor in
                self?.lastPoll = Date()
                self?.isReceiverConnected = true
            }
        }
    }

    func start() {
        server.start()
        if monitor == nil {
            monitor = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.isReceiverConnected = self.lastPoll.map {
                        Date().timeIntervalSince($0) < 7
                    } ?? false
                }
            }
        }
    }

    func setSubtitle(_ text: String) { server.update(text) }

    func stop() {
        monitor?.invalidate()
        monitor = nil
        server.stop()
        isReady = false
        isReceiverConnected = false
    }
}

// Kept off the main actor; all NWListener access runs on a dedicated queue.
// A random free port eliminates Address Already In Use / NWError 48.
private final class REBOXHTTPServer: @unchecked Sendable {
    var onReady: ((UInt16) -> Void)?
    var onPoll: (() -> Void)?

    private let queue = DispatchQueue(label: "rebox.translator.http")
    private let lock = NSLock()
    private var currentCaption = ""
    private var listener: NWListener?

    func start() {
        queue.async { [self] in
            guard listener == nil else { return }
            do {
                let candidate = try NWListener(using: .tcp, on: .any)
                listener = candidate
                candidate.stateUpdateHandler = { [weak self] state in
                    if case .ready = state, let port = candidate.port?.rawValue {
                        self?.onReady?(port)
                    }
                }
                candidate.newConnectionHandler = { [weak self] connection in
                    self?.receive(connection)
                }
                candidate.start(queue: queue)
            } catch {
                // Never report connection success when the listener failed.
            }
        }
    }

    func stop() {
        queue.async { [self] in
            listener?.cancel()
            listener = nil
        }
    }

    func update(_ text: String) {
        lock.lock()
        currentCaption = text
        lock.unlock()
    }

    private func latestCaption() -> String {
        lock.lock()
        defer { lock.unlock() }
        return currentCaption
    }

    private func receive(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self else { connection.cancel(); return }
            let text = String(data: data ?? Data(), encoding: .utf8) ?? ""
            let first = text.components(separatedBy: "\r\n").first ?? ""
            let path = first.split(separator: " ").dropFirst().first
                .map(String.init)?.components(separatedBy: "?").first ?? "/"
            let bytes: Data
            let type: String
            let status: String
            switch path {
            case "/", "/tv":
                bytes = Data(REBOXTVHTML.page.utf8)
                type = "text/html; charset=utf-8"
                status = "200 OK"
            case "/state":
                bytes = (try? JSONSerialization.data(withJSONObject: [
                    "subtitle": self.latestCaption()
                ])) ?? Data("{}".utf8)
                type = "application/json; charset=utf-8"
                status = "200 OK"
                self.onPoll?()
            default:
                bytes = Data("Not Found".utf8)
                type = "text/plain; charset=utf-8"
                status = "404 Not Found"
            }
            let headers = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(bytes.count)\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
            var response = Data(headers.utf8)
            response.append(bytes)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}

private enum REBOXLAN {
    static func ipv4() -> String {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let head = list else { return "127.0.0.1" }
        defer { freeifaddrs(head) }
        var item: UnsafeMutablePointer<ifaddrs>? = head
        while let current = item {
            let entry = current.pointee
            if let addr = entry.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET),
               String(cString: entry.ifa_name) == "en0" {
                var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &buffer,
                               socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                    return String(cString: buffer)
                }
            }
            item = entry.ifa_next
        }
        return "127.0.0.1"
    }
}
