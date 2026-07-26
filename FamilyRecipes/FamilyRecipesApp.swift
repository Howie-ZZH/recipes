import SwiftUI
import SwiftData

@main
struct FamilyRecipesApp: App {
    @State private var appState = AppState()
    
    let container: ModelContainer
    
    init() {
        let schema = Schema([FamilyMember.self, Dish.self, MealOrder.self, FoodDiary.self])
        let config = ModelConfiguration("default", schema: schema)
        
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Migration failed — nuke the old store and recreate
            print("[FamilyRecipesApp] Migration failed: \(error). Nuking old store...")
            
            // Find Application Support directory and remove ALL store-related files
            if let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: appSupportDir,
                        includingPropertiesForKeys: nil
                    )
                    for fileURL in contents {
                        let name = fileURL.lastPathComponent
                        // Remove default.store, default.store-shm, default.store-wal,
                        // and any _SUPPORT external data directories
                        if name.hasPrefix("default") {
                            try? FileManager.default.removeItem(at: fileURL)
                            print("[FamilyRecipesApp] Removed: \(name)")
                        }
                    }
                } catch {
                    print("[FamilyRecipesApp] Failed to enumerate AppSupport: \(error)")
                }
            }
            
            do {
                container = try ModelContainer(for: schema, configurations: [config])
                print("[FamilyRecipesApp] Successfully recreated store after cleanup.")
            } catch {
                fatalError("[FamilyRecipesApp] Cannot create ModelContainer even after cleanup: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .modelContainer(container)
        }
    }
}
