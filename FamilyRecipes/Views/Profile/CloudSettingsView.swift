import SwiftUI

struct CloudSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var url = "https://sbghojlespqzdelxrarh.supabase.co"
    @State private var key = "sb_publishable_dsiukZ2DCrqIB6FzNZ7-Lw_h1Kae7J8"
    
    @State private var testStatus = ""
    @State private var isTesting = false
    @State private var testSuccess = false
    @State private var showingCopyAlert = false
    
    let sqlScript = """
    -- 1. 创建家庭成员表
    CREATE TABLE IF NOT EXISTS family_members (
        id UUID PRIMARY KEY,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL,
        role TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- 2. 创建菜谱表
    CREATE TABLE IF NOT EXISTS dishes (
        id UUID PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        tags TEXT[] NOT NULL,
        emoji TEXT NOT NULL,
        dish_description TEXT NOT NULL,
        ingredients TEXT[] NOT NULL,
        cook_note TEXT NOT NULL,
        is_favorite BOOLEAN NOT NULL,
        image_base64 TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- 3. 创建今日点餐表
    CREATE TABLE IF NOT EXISTS meal_orders (
        id UUID PRIMARY KEY,
        member_id UUID REFERENCES family_members(id) ON DELETE CASCADE,
        dish_id UUID REFERENCES dishes(id) ON DELETE SET NULL,
        order_date TIMESTAMPTZ NOT NULL,
        note TEXT NOT NULL,
        is_fulfilled BOOLEAN NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );
    """
    
    var body: some View {
        NavigationStack {
            Form {
                Section("云原生架构说明") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "icloud.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                            Text("已启用纯云端实时读写")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        
                        Text("当前 App 已全面采用纯云端架构，所有菜谱、家庭成员及点单信息均直接安全地存储于您的 Supabase 专有云数据库中。多端瞬间对齐，无任何本地缓存同步冲突。")
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                            .lineSpacing(4)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Supabase / MemFire 配置"), footer: Text("默认已为您填入您的私有云数据库凭据，如需修改，请在上方贴入新的 Project URL 与 anon key。")) {
                    TextField("Project URL", text: $url)
                        .autocorrectionDisabled()
                        .onChange(of: url) { _, newValue in
                            appState.setSupabaseURL(newValue)
                        }
                    
                    SecureField("anon key", text: $key)
                        .autocorrectionDisabled()
                        .onChange(of: key) { _, newValue in
                            appState.setSupabaseKey(newValue)
                        }
                    
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isTesting ? "正在连通云端并同步数据..." : "测试连接并拉取数据")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(Color(hex: "#FF5E36"))
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(isTesting || url.isEmpty || key.isEmpty)
                    
                    if !testStatus.isEmpty {
                        Text(testStatus)
                            .font(.caption)
                            .foregroundColor(testSuccess ? .green : .red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                Section(header: Text("云端一键建表脚本 (SQL)"), footer: Text("提示：使用云数据库前，请务必先复制此脚本，前往您的 Supabase 网页的 SQL Editor 中粘贴并点击 'Run' 运行建表。")) {
                    Button {
                        UIPasteboard.general.string = sqlScript
                        withAnimation {
                            showingCopyAlert = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showingCopyAlert = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc.fill")
                            Text(showingCopyAlert ? "复制成功！" : "一键复制建表 SQL 脚本")
                        }
                        .foregroundColor(Color(hex: "#FF5E36"))
                        .fontWeight(.semibold)
                    }
                    
                    Text(sqlScript)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Color(.secondaryLabel))
                        .frame(height: 150)
                        .cornerRadius(8)
                }
            }
            .navigationTitle("云端同步设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FF5E36"))
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                url = appState.supabaseURL
                key = appState.supabaseKey
                
                if !url.isEmpty && !key.isEmpty {
                    testSuccess = true
                }
            }
        }
    }
    
    private func testConnection() {
        isTesting = true
        testStatus = ""
        
        Task {
            do {
                // Test connection by fetching members
                _ = try await SupabaseManager.shared.fetchMembers(url: url, key: key)
                
                await appState.fetchAllData()
                
                await MainActor.run {
                    testSuccess = true
                    testStatus = "✅ 连接成功！已和云端数据库实时同步。"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testSuccess = false
                    testStatus = "❌ 连接失败: \(error.localizedDescription)\n请确保您已经在 Supabase SQL Editor 中运行了建表 SQL 脚本！"
                    isTesting = false
                }
            }
        }
    }
}
