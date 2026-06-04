import SwiftUI

struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0
    @State private var showingCloudSettings = false
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                OrderView()
                    .tabItem {
                        Label("今日点餐", systemImage: "fork.knife")
                    }
                    .tag(0)
                
                DishListView()
                    .tabItem {
                        Label("共享菜谱", systemImage: "book.pages")
                    }
                    .tag(1)
                
                CookDashboardView()
                    .tabItem {
                        Label("掌勺面板", systemImage: "cooktop.fill")
                    }
                    .tag(2)
            }
            .tint(Color(hex: "#FF5E36")) // Warm accent color for active tabs
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Header profile switcher
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.title3)
                            .foregroundColor(Color(hex: "#FF5E36"))
                        
                        Text("家庭餐桌")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.black)
                            .foregroundColor(Color(hex: "#FF5E36"))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Cloud Settings Button (No more cloud sync toggles needed as we are pure cloud native!)
                        Button {
                            showingCloudSettings = true
                        } label: {
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.green)
                        }
                        
                        Button {
                            // Return to member selection with animation
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                appState.setActiveMember(nil)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(appState.currentMember?.emoji ?? "👤")
                                    .font(.body)
                                
                                Text(appState.currentMember?.name ?? "切换角色")
                                    .font(.system(.footnote, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(hex: "#FF5E36"))
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "#FF5E36").opacity(0.7))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#FF5E36").opacity(0.1))
                            )
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCloudSettings) {
                CloudSettingsView()
                    .environment(appState)
            }
            .task {
                // Pull down data on appear
                await appState.fetchAllData()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await appState.fetchAllData()
                    }
                }
            }
        }
    }
}
