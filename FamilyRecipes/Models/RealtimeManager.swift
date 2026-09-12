import Foundation

@Observable
@MainActor
final class RealtimeManager {
    static let shared = RealtimeManager()
    
    var isConnected: Bool = false
    var isServerSupported: Bool = true
    var lastEventReceivedAt: Date?
    
    var onRemoteChange: (() -> Void)?
    
    @ObservationIgnored
    private var webSocketTask: URLSessionWebSocketTask?
    @ObservationIgnored
    private var pingTimer: Task<Void, Never>?
    @ObservationIgnored
    private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored
    private var currentURL: String = ""
    @ObservationIgnored
    private var currentKey: String = ""
    @ObservationIgnored
    private var reconnectAttempts: Int = 0
    
    private init() {}
    
    // Helper to derive WebSocket URL from HTTP/HTTPS base URL
    static func deriveWebSocketURL(from httpURL: String, key: String = "") -> URL? {
        var base = httpURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return nil }
        
        // 1. Explicit WebSocket URL
        if base.hasPrefix("ws://") || base.hasPrefix("wss://") {
            return URL(string: base)
        }
        
        // 2. Supabase Cloud endpoints explicitly support Realtime WebSockets
        if base.contains("supabase.co") {
            if base.hasPrefix("http://") {
                base = "ws://" + base.dropFirst(7)
            } else if base.hasPrefix("https://") {
                base = "wss://" + base.dropFirst(8)
            }
            if base.hasSuffix("/") {
                base.removeLast()
            }
            base += "/realtime/v1/websocket?apikey=\(key)&vsn=1.0.0"
            return URL(string: base)
        }
        
        // 3. Standalone PostgREST (pure HTTP REST) does not host WebSocket; return nil to avoid connection failure noise
        return nil
    }
    
    func connect(url: String, key: String) {
        guard !url.isEmpty else { return }
        
        if url != currentURL {
            isServerSupported = true
            reconnectAttempts = 0
        }
        
        self.currentURL = url
        self.currentKey = key
        
        guard isServerSupported else { return }
        
        disconnect()
        
        guard let wsURL = Self.deriveWebSocketURL(from: url, key: key) else {
            print("[RealtimeManager] Invalid WebSocket URL derived from \(url)")
            return
        }
        
        let session = URLSession(configuration: .default)
        var request = URLRequest(url: wsURL)
        if !key.isEmpty {
            request.setValue(key, forHTTPHeaderField: "apikey")
            if key.hasPrefix("eyJ") {
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            }
        }
        
        let task = session.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()
        
        // Start listening
        listenForMessages(task: task)
        
        // Start heartbeats
        startPingTimer()
    }
    
    func disconnect() {
        pingTimer?.cancel()
        pingTimer = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
    
    private func listenForMessages(task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self, self.webSocketTask === task else { return }
                
                switch result {
                case .success(let message):
                    self.isConnected = true
                    self.reconnectAttempts = 0
                    self.handleIncomingMessage(message)
                    self.listenForMessages(task: task)
                    
                case .failure(let error):
                    let nsError = error as NSError
                    self.isConnected = false
                    
                    // Code -1011 indicates HTTP error during handshake (e.g. 404 / 400 because standalone PostgREST doesn't host /realtime WebSocket)
                    if nsError.code == -1011 {
                        self.isServerSupported = false
                        print("[RealtimeManager] Server \(self.currentURL) does not host a WebSocket realtime endpoint. Smoothly using Adaptive Heartbeat Polling.")
                        return
                    }
                    
                    print("[RealtimeManager] Socket disconnected: \(error.localizedDescription)")
                    self.scheduleReconnect()
                }
            }
        }
    }
    
    private func handleIncomingMessage(_ message: URLSessionWebSocketTask.Message) {
        lastEventReceivedAt = Date()
        // Trigger immediate incremental delta sync on receiving broadcast
        onRemoteChange?()
    }
    
    private func startPingTimer() {
        pingTimer?.cancel()
        pingTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 25_000_000_000) // 25s
                if Task.isCancelled { break }
                guard let ws = self.webSocketTask else { break }
                
                ws.sendPing { error in
                    Task { @MainActor in
                        if let error = error {
                            self.isConnected = false
                        } else {
                            self.isConnected = true
                        }
                    }
                }
            }
        }
    }
    
    private func scheduleReconnect() {
        guard !currentURL.isEmpty, isServerSupported else { return }
        reconnectTask?.cancel()
        
        if reconnectAttempts >= 3 {
            print("[RealtimeManager] Max reconnect attempts reached. Switching to Adaptive Polling.")
            return
        }
        
        let delay = min(pow(2.0, Double(reconnectAttempts)), 16.0)
        reconnectAttempts += 1
        
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled {
                self.connect(url: self.currentURL, key: self.currentKey)
            }
        }
    }
    
    // Test simulator for unit tests
    func simulateIncomingEvent() {
        self.lastEventReceivedAt = Date()
        self.onRemoteChange?()
    }
}
