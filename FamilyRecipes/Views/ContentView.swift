import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Group {
            if appState.activeMemberId == nil {
                ProfileSelectionView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: appState.activeMemberId)
        .task {
            // Trigger offline-first sync engine
            await SyncEngine.shared.syncDown(context: modelContext, appState: appState)
        }
    }
}

