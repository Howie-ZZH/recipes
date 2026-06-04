import SwiftUI

struct MemberManageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var editingMember: FamilyMember?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(appState.members) { member in
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
        withAnimation {
            for index in offsets {
                let member = appState.members[index]
                let memberId = member.id
                
                Task {
                    await appState.deleteMember(id: memberId)
                }
            }
        }
    }
}

// Edit Member Sheet
struct EditMemberSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var member: FamilyMember
    
    @State private var isSaving = false
    
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
                        isSaving = true
                        Task {
                            await appState.updateMember(member)
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(Color(hex: "#FF5E36"))
                    .disabled(isSaving)
                }
            }
        }
    }
}
