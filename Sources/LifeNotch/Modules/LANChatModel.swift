import Foundation
import Network
import CryptoKit

// LANChatModel.swift
// Chat with other LifeNotch users on the SAME Wi-Fi / network, with no account and no server.
//  - You and a friend type the same room code. Your Macs find each other with Bonjour (Apple's local discovery).
//  - Every message is encrypted (AES-GCM) with a key made from the room code, so only people who know the
//    code can read it. Handles are random ("Guest-4821") unless you change yours.
//  - Nothing is saved: messages live in memory and vanish when you leave the room.
// macOS shows its own "Local Network" permission question the first time.

struct LANMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    var handle: String
    var text: String
    var time = Date()
    var isMine = false

    enum CodingKeys: String, CodingKey { case id, handle, text, time }
}

final class LANChatModel: ObservableObject {
    @Published private(set) var messages: [LANMessage] = []
    @Published private(set) var peerCount = 0
    @Published private(set) var isOn = false
    @Published private(set) var status = ""

    static let serviceType = "_lifenotch-chat._tcp"

    private let queue = DispatchQueue(label: "lifenotch.chat")
    private let myID = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(8))
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [String: NWConnection] = [:]      // key: remote service name
    private var buffers: [ObjectIdentifier: Data] = [:]
    private var key: SymmetricKey?
    private var roomTag = ""
    private var handle = "Guest"

    // MARK: Room code -> key (pure, easy to test)

    static func key(for room: String) -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: Data(("lifenotch-chat-key:" + room.lowercased()).utf8)))
    }

    static func tag(for room: String) -> String {
        SHA256.hash(data: Data(("lifenotch-chat-tag:" + room.lowercased()).utf8)).prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    static func frame(_ message: LANMessage, key: SymmetricKey) throws -> Data {
        let json = try JSONEncoder().encode(message)
        guard let sealed = try AES.GCM.seal(json, using: key).combined else { throw CocoaError(.coderInvalidValue) }
        var length = UInt32(sealed.count).bigEndian
        return Data(bytes: &length, count: 4) + sealed
    }

    /// Pulls complete frames off the front of `buffer` and decrypts them.
    static func unframe(_ buffer: inout Data, key: SymmetricKey) -> [LANMessage] {
        var result: [LANMessage] = []
        while buffer.count >= 4 {
            let length = Int(buffer.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) })
            if length > 20_000 { buffer.removeAll(); break }                       // not ours: drop
            guard buffer.count >= 4 + length else { break }
            let body = buffer.subdata(in: buffer.startIndex + 4 ..< buffer.startIndex + 4 + length)
            buffer = Data(buffer.dropFirst(4 + length))
            if let box = try? AES.GCM.SealedBox(combined: body),
               let plain = try? AES.GCM.open(box, using: key),
               let message = try? JSONDecoder().decode(LANMessage.self, from: plain) {
                result.append(message)
            }
        }
        return result
    }

    // MARK: Joining and leaving

    func join(room: String, handle: String) {
        let code = room.trimmingCharacters(in: .whitespaces)
        guard !isOn, code.count >= 4 else { status = "Pick a room code with at least 4 characters."; return }
        self.handle = handle.isEmpty ? "Guest" : String(handle.prefix(24))
        key = Self.key(for: code)
        roomTag = Self.tag(for: code)
        isOn = true
        status = "Looking for people with the same code…"
        queue.async { [weak self] in self?.startNetworking() }
    }

    func leave() {
        isOn = false
        peerCount = 0
        status = ""
        messages = []
        queue.async { [weak self] in
            guard let self = self else { return }
            self.browser?.cancel(); self.browser = nil
            self.listener?.cancel(); self.listener = nil
            self.connections.values.forEach { $0.cancel() }
            self.connections = [:]
            self.buffers = [:]
        }
    }

    func send(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isOn, !clean.isEmpty, let key = key else { return }
        let message = LANMessage(handle: handle, text: String(clean.prefix(2000)))
        var mine = message
        mine.isMine = true
        messages.append(mine)
        queue.async { [weak self] in
            guard let self = self, let data = try? Self.frame(message, key: key) else { return }
            for connection in self.connections.values {
                connection.send(content: data, completion: .contentProcessed { _ in })
            }
        }
    }

    // MARK: Networking (runs on `queue`)

    private func startNetworking() {
        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(name: "ln-\(roomTag)-\(myID)", type: Self.serviceType)
            listener.newConnectionHandler = { [weak self] connection in
                // The remote name isn't known for incoming connections; key by object identity.
                self?.adopt(connection, name: "in-\(UUID().uuidString)")
            }
            listener.stateUpdateHandler = { [weak self] state in
                if case .failed(let error) = state {
                    DispatchQueue.main.async { self?.status = "Couldn't start: \(error.localizedDescription)" }
                }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            DispatchQueue.main.async { self.status = "Couldn't start: \(error.localizedDescription)" }
            return
        }

        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self else { return }
            for result in results {
                guard case let .service(name, _, _, _) = result.endpoint,
                      name.hasPrefix("ln-\(self.roomTag)-"), !name.hasSuffix(self.myID),
                      self.connections[name] == nil else { continue }
                // Only the peer with the smaller ID dials, so each pair makes exactly one connection.
                let theirID = String(name.suffix(8))
                if self.myID < theirID {
                    let connection = NWConnection(to: result.endpoint, using: .tcp)
                    self.adopt(connection, name: name)
                }
            }
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    private func adopt(_ connection: NWConnection, name: String) {
        connections[name] = connection
        let id = ObjectIdentifier(connection)
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.updatePeers()
                self.receive(on: connection)
            case .failed, .cancelled:
                self.connections[name] = nil
                self.buffers[id] = nil
                self.updatePeers()
            default: break
            }
        }
        connection.start(queue: queue)
    }

    private func updatePeers() {
        let count = connections.values.filter { connection in
            if case .ready = connection.state { return true }
            return false
        }.count
        DispatchQueue.main.async {
            self.peerCount = count
            self.status = count == 0 ? "Looking for people with the same code…" : ""
        }
    }

    private func receive(on connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self = self, let key = self.key else { return }
            if let data = data, !data.isEmpty {
                var buffer = self.buffers[id] ?? Data()
                buffer.append(data)
                let incoming = Self.unframe(&buffer, key: key)
                self.buffers[id] = buffer
                if !incoming.isEmpty { DispatchQueue.main.async { self.messages.append(contentsOf: incoming) } }
            }
            if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receive(on: connection)
            }
        }
    }
}
