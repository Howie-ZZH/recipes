import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
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
            // Trigger initial sync and start smart real-time listener + foreground polling
            await SyncEngine.shared.syncDown(context: modelContext, appState: appState)
            SyncEngine.shared.startRealtimeAndPolling(context: modelContext, appState: appState, interval: appState.pollingInterval)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await SyncEngine.shared.syncDown(context: modelContext, appState: appState)
                }
                SyncEngine.shared.startRealtimeAndPolling(context: modelContext, appState: appState, interval: appState.pollingInterval)
            } else {
                SyncEngine.shared.stopRealtimeAndPolling()
            }
        }
    }
}

