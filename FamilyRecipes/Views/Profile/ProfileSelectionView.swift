import SwiftUI
import SwiftData

struct ProfileSelectionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FamilyMember.name) private var members: [FamilyMember]
    
    @State private var showingAddSheet = false
    @State private var showSettingsSheet = false
    @State private var showCloudSettingsSheet = false
    
    // Flexible 3-column layout for avatars
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            // Warm gradient background
            LinearGradient(
                colors: [Color(.systemGroupedBackground), Color(hex: "#FFF4E8")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Action Bar
                HStack {
                    Spacer()
                    Button {
                        showCloudSettingsSheet = true
                    } label: {
                        Image(systemName: "cloud.fill")
                            .font(.title3)
                            .foregroundColor(Color(hex: "#FF5E36"))
                            .padding(10)
                            .background(Circle().fill(Color(hex: "#FF5E36").opacity(0.1)))
                    }
                    .buttonStyle(ScaledButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Warm Header
                        VStack(spacing: 8) {
                            Text("🥘 家庭餐桌")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(Color(hex: "#FF5E36"))
                            
                            Text("今天谁来吃饭？")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(Color(.secondaryLabel))
                        }
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                        
                        // Error Alert Banner
                        if !appState.networkError.isEmpty {
                            Text(appState.networkError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Sync Indicator (Non-blocking)
                        if appState.isSyncing {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("云端同步中...")
                                    .font(.caption)
                                    .foregroundColor(Color(.secondaryLabel))
                            }
                        }
                        
                        // Members Grid
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(members) { member in
                                Button {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        appState.activeMemberId = member.id
                                    }
                                } label: {
                                    VStack(spacing: 10) {
                                        // Avatar circle with dynamic glow
                                        ZStack {
                                            Circle()
                                                .fill(LinearGradient(
                                                    colors: [Color(hex: "#FFAC81"), Color(hex: "#FF928B")],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ))
                                                .frame(width: 76, height: 76)
                                                .shadow(color: Color(hex: "#FF928B").opacity(0.35), radius: 8, x: 0, y: 4)
                                            
                                            Text(member.emoji)
                                                .font(.system(size: 38))
                                        }
                                        
                                        VStack(spacing: 4) {
                                            Text(member.name)
                                                .font(.system(.body, design: .rounded))
                                                .fontWeight(.bold)
                                                .foregroundColor(Color(.label))
                                                .lineLimit(1)
                                            
                                            Text(member.role == "Cook" ? "掌勺人" : "家庭成员")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(member.role == "Cook" ? Color(hex: "#FF5E36") : Color(.tertiaryLabel))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(
                                                    Capsule()
                                                        .fill(member.role == "Cook" ? Color(hex: "#FF5E36").opacity(0.12) : Color.clear)
                                                )
                                        }
                                    }
                                }
                                .buttonStyle(ScaledButtonStyle())
                            }
                            
                            // Add Member Button
                            Button {
                                showingAddSheet = true
                            } label: {
                                VStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .strokeBorder(Color(hex: "#FF5E36").opacity(0.4), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [6, 6]))
                                            .background(Circle().fill(Color(hex: "#FF5E36").opacity(0.04)))
                                            .frame(width: 76, height: 76)
                                        
                                        Image(systemName: "plus")
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundColor(Color(hex: "#FF5E36"))
                                    }
                                    
                                    Text("添加成员")
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(hex: "#FF5E36"))
                                }
                            }
                            .buttonStyle(ScaledButtonStyle())
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        
                        // Footer settings button
                        Button {
                            showSettingsSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "gearshape.fill")
                                Text("管理家庭成员")
                            }
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "#FF5E36"))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color(hex: "#FF5E36").opacity(0.1)))
                        }
                        .buttonStyle(ScaledButtonStyle())
                        .padding(.top, 10)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddMemberSheet()
                .environment(appState)
        }
        .sheet(isPresented: $showSettingsSheet) {
            MemberManageView()
                .environment(appState)
        }
        .sheet(isPresented: $showCloudSettingsSheet) {
            CloudSettingsView()
                .environment(appState)
        }
        .task {
            await SyncEngine.shared.syncDown(context: modelContext, appState: appState)
        }
        .refreshable {
            await SyncEngine.shared.syncDown(context: modelContext, appState: appState)
        }
    }
}

// Custom Micro-Animation Button Style
struct ScaledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Color Hex Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 1)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Add Member Sheet
struct AddMemberSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedEmoji = "👨"
    @State private var isCook = false
    @State private var isSaving = false
    @State private var saveErrorMessage = ""
    
    let emojis = ["👨", "👩‍🍳", "👧", "👦", "👵", "👴", "🦁", "🐼", "🦊", "🐱", "🐶", "🦖"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("名字（例如：爸爸、宝贝）", text: $name)
                        .autocorrectionDisabled()
                    
                    Toggle("是掌勺人（可以查看买菜汇总）", isOn: $isCook)
                        .tint(Color(hex: "#FF5E36"))
                }
                
                Section("选择头像 Emoji") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(emojis, id: \.self) { emoji in
                                Text(emoji)
                                    .font(.system(size: 38))
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(selectedEmoji == emoji ? Color(hex: "#FF5E36").opacity(0.18) : Color.clear)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(selectedEmoji == emoji ? Color(hex: "#FF5E36") : Color.clear, lineWidth: 2)
                                    )
                                    .onTapGesture {
                                        withAnimation(.interactiveSpring()) {
                                            selectedEmoji = emoji
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("添加家庭成员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FF5E36"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        let newMember = FamilyMember(
                            name: name.isEmpty ? "新成员" : name,
                            emoji: selectedEmoji,
                            role: isCook ? "Cook" : "Member"
                        )
                        modelContext.insert(newMember)
                        SyncEngine.shared.push(newMember, appState: appState)
                        dismiss()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(Color(hex: "#FF5E36"))
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .overlay(
                Group {
                    if !saveErrorMessage.isEmpty {
                        VStack {
                            Spacer()
                            Text(saveErrorMessage)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Capsule().fill(Color.red.opacity(0.9)))
                                .padding(.bottom, 20)
                        }
                    }
                }
            )
        }
    }
}
