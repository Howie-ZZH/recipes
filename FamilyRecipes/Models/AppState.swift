import SwiftUI
import SwiftData

@Observable
@MainActor
final class AppState {
    var activeMemberId: UUID? {
        didSet {
            if let id = activeMemberId {
                UserDefaults.standard.set(id.uuidString, forKey: "activeMemberId")
            } else {
                UserDefaults.standard.removeObject(forKey: "activeMemberId")
            }
        }
    }
    
    // Cloud Settings Properties
    var isCloudSyncEnabled: Bool = true
    var supabaseURL: String = "http://47.79.236.127:3000"
    var supabaseKey: String = ""
    
    // UI Feedback States
    var isSyncing: Bool = false
    var networkError: String = ""
    var pollingInterval: TimeInterval = 15
    var isRealtimeConnected: Bool = false
    var pendingOutboxCount: Int = 0
    
    // Sync Cursor for Delta Sync
    var lastSyncTimestamp: Date? {
        didSet {
            if let date = lastSyncTimestamp {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "lastSyncTimestamp")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastSyncTimestamp")
            }
        }
    }
    
    init() {
        let savedURL = UserDefaults.standard.string(forKey: "supabaseUrl") ?? "http://47.79.236.127:3000"
        self.supabaseURL = savedURL
        self.supabaseKey = UserDefaults.standard.string(forKey: "supabaseKey") ?? ""
        
        let savedId = UserDefaults.standard.string(forKey: "activeMemberId") ?? ""
        if !savedId.isEmpty {
            self.activeMemberId = UUID(uuidString: savedId)
        }
        
        let savedTimestamp = UserDefaults.standard.double(forKey: "lastSyncTimestamp")
        if savedTimestamp > 0 {
            self.lastSyncTimestamp = Date(timeIntervalSince1970: savedTimestamp)
        }
    }
    
    func resetSyncCursor() {
        self.lastSyncTimestamp = nil
    }
    
    // MARK: - Cloud Configurations
    
    func setSupabaseURL(_ url: String) {
        let cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        self.supabaseURL = cleanURL
        UserDefaults.standard.set(cleanURL, forKey: "supabaseUrl")
    }
    
    func setSupabaseKey(_ key: String) {
        self.supabaseKey = key
        UserDefaults.standard.set(key, forKey: "supabaseKey")
    }
    
    func logout() {
        self.activeMemberId = nil
    }
}
