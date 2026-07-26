import SwiftUI
import SwiftData

struct CloudSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    @State private var url = "http://47.79.236.127:3000"
    @State private var key = ""
    
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
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
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
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- 3. 创建今日点餐表
    CREATE TABLE IF NOT EXISTS meal_orders (
        id UUID PRIMARY KEY,
        member_id UUID REFERENCES family_members(id) ON DELETE CASCADE,
        dish_id UUID REFERENCES dishes(id) ON DELETE SET NULL,
        order_date TIMESTAMPTZ NOT NULL,
        note TEXT NOT NULL,
        is_fulfilled BOOLEAN NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- 4. 创建美食日记表
    CREATE TABLE IF NOT EXISTS food_diaries (
        id UUID PRIMARY KEY,
        diary_date DATE NOT NULL,
        member_id UUID REFERENCES family_members(id) ON DELETE CASCADE,
        dish_id UUID REFERENCES dishes(id) ON DELETE CASCADE,
        rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
        comment TEXT NOT NULL,
        image_base64 TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- 5. 为已有表添加 updated_at 列（如果缺失）
    ALTER TABLE family_members ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
    ALTER TABLE dishes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
    ALTER TABLE meal_orders ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
    ALTER TABLE food_diaries ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
    """
    
    var body: some View {
        NavigationStack {
            Form {
                Section("自建云端架构说明") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "server.rack")
                                .font(.title3)
                                .foregroundColor(.green)
                            Text("已连接自建 PostgREST 服务")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        
                        Text("当前 App 已连接到您自建的 PostgreSQL + PostgREST 后端服务。所有菜谱、家庭成员及点单信息均直接存储于您的私有数据库中，数据完全自主掌控。")
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                            .lineSpacing(4)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("PostgREST 服务器配置"), footer: Text("默认已为您填入自建服务器地址。如需修改，请在上方贴入新的服务器 URL。API Key 可留空（取决于您的 PostgREST 配置）。")) {
                    TextField("服务器 URL（如 http://IP:3000）", text: $url)
                        .autocorrectionDisabled()
                        .onChange(of: url) { _, newValue in
                            appState.setSupabaseURL(newValue)
                        }
                    
                    SecureField("API Key（可选）", text: $key)
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
                    .disabled(isTesting || url.isEmpty)
                    
                    if !testStatus.isEmpty {
                        Text(testStatus)
                            .font(.caption)
                            .foregroundColor(testSuccess ? .green : .red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                Section(header: Text("数据库建表脚本 (SQL)"), footer: Text("提示：使用前请先将此脚本在您的 PostgreSQL 客户端（如 psql 或 pgAdmin）中执行，以创建所需的数据表。")) {
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
                
                await SyncEngine.shared.syncDown(context: modelContext, appState: appState)
                
                await MainActor.run {
                    testSuccess = true
                    testStatus = "✅ 连接成功！已和云端数据库实时同步。"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testSuccess = false
                    testStatus = "❌ 连接失败: \(error.localizedDescription)\n请确保您的 PostgREST 服务正在运行，且已执行了建表 SQL 脚本！"
                    isTesting = false
                }
            }
        }
    }
}
