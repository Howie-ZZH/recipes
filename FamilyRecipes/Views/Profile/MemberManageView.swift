import SwiftUI
import SwiftData

struct MemberManageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FamilyMember.name) private var members: [FamilyMember]
    
    @State private var editingMember: FamilyMember?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(members) { member in
                    HStack(spacing: 16) {
                        Text(member.emoji)
                            .font(.system(size: 32))
                            .padding(8)
                            .background(Circle().fill(Color(hex: "#FF5E36").opacity(0.1)))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name)
                                .font(.headline)
                            Text(member.role == "Cook" ? "掌勺人 (拥有一键买菜汇总权限)" : "家庭成员")
                                .font(.caption)
                                .foregroundColor(Color(.secondaryLabel))
                        }
                        
                        Spacer()
                        
                        Button {
                            editingMember = member
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(Color(hex: "#FF5E36"))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteMembers)
            }
            .navigationTitle("管理家庭成员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FF5E36"))
                    .fontWeight(.bold)
                }
            }
            .sheet(item: $editingMember) { member in
                EditMemberSheet(member: member)
                    .environment(appState)
            }
        }
    }
    
    private func deleteMembers(offsets: IndexSet) {
        for index in offsets {
            let member = members[index]
            let memberId = member.id
            modelContext.delete(member)
            SyncEngine.shared.deleteMember(id: memberId, appState: appState)
        }
    }
}

// Edit Member Sheet
struct EditMemberSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var member: FamilyMember
    
    @State private var isSaving = false
    @State private var saveErrorMessage = ""
    
    let emojis = ["👨", "👩‍🍳", "👧", "👦", "👵", "👴", "🦁", "🐼", "🦊", "🐱", "🐶", "🦖"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("修改基本信息") {
                    TextField("名字", text: $member.name)
                    
                    Toggle("是掌勺人", isOn: Binding(
                        get: { member.role == "Cook" },
                        set: { member.role = $0 ? "Cook" : "Member" }
                    ))
                    .tint(Color(hex: "#FF5E36"))
                }
                
                Section("修改头像 Emoji") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(emojis, id: \.self) { emoji in
                                Text(emoji)
                                    .font(.system(size: 38))
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(member.emoji == emoji ? Color(hex: "#FF5E36").opacity(0.18) : Color.clear)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(member.emoji == emoji ? Color(hex: "#FF5E36") : Color.clear, lineWidth: 2)
                                    )
                                    .onTapGesture {
                                        withAnimation(.interactiveSpring()) {
                                            member.emoji = emoji
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("编辑成员信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        member.updatedAt = Date()
                        SyncEngine.shared.push(member, appState: appState)
                        dismiss()
                    } label: {
                        Text("保存")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(Color(hex: "#FF5E36"))
                    .disabled(isSaving)
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
