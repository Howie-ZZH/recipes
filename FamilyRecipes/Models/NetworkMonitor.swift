import Foundation
import Network

@Observable
@MainActor
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    var isConnected: Bool = true
    var isCellular: Bool = false
    var isExpensive: Bool = false
    
    var onStatusChange: ((Bool) -> Void)?
    
    @ObservationIgnored
    private var monitor: NWPathMonitor?
    
    @ObservationIgnored
    private let monitorQueue = DispatchQueue(label: "com.familyrecipes.networkmonitor")
    
    init() {
        start()
    }
    
    func start() {
        guard monitor == nil else { return }
        let mon = NWPathMonitor()
        mon.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let connected = (path.status == .satisfied)
                let cellular = path.usesInterfaceType(.cellular)
                let expensive = path.isExpensive
                
                let changed = (self?.isConnected != connected)
                self?.isConnected = connected
                self?.isCellular = cellular
                self?.isExpensive = expensive
                
                if changed {
                    self?.onStatusChange?(connected)
                }
            }
        }
        mon.start(queue: monitorQueue)
        self.monitor = mon
    }
    
    func stop() {
        monitor?.cancel()
        monitor = nil
    }
    
    // Test helper to simulate connection toggling in unit tests
    func simulateConnection(connected: Bool, cellular: Bool = false, expensive: Bool = false) {
        let changed = (self.isConnected != connected)
        self.isConnected = connected
        self.isCellular = cellular
        self.isExpensive = expensive
        if changed {
            self.onStatusChange?(connected)
        }
    }
}
