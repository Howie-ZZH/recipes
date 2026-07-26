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
    
    init() {
        let savedURL = UserDefaults.standard.string(forKey: "supabaseUrl") ?? "http://47.79.236.127:3000"
        self.supabaseURL = savedURL
        self.supabaseKey = UserDefaults.standard.string(forKey: "supabaseKey") ?? ""
        
        let savedId = UserDefaults.standard.string(forKey: "activeMemberId") ?? ""
        if !savedId.isEmpty {
            self.activeMemberId = UUID(uuidString: savedId)
        }
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
