import SwiftUI

@main
struct FamilyRecipesApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .task {
                    // Asynchronously fetch all data from Supabase Cloud on startup
                    await appState.fetchAllData()
                }
        }
    }
}
