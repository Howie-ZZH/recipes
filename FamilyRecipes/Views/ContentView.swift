import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Group {
            if appState.currentMember == nil {
                ProfileSelectionView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: appState.currentMember)
    }
}

#Preview {
    ContentView()
        .environment(SampleData.previewState)
}
