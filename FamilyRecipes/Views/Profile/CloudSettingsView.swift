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

    -- 5. 为已有表添加 updated_at 与 deleted_at 列（如果缺失）
    ALTER TABLE family_members ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
    ALTER TABLE family_members ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
    ALTER TABLE dishes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
    ALTER TABLE dishes ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
    ALTER TABLE meal_orders ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
    ALTER TABLE meal_orders ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
    ALTER TABLE food_diaries ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
    ALTER TABLE food_diaries ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
    """
    
    var lastSyncText: String {
        guard let date = appState.lastSyncTimestamp else {
            return "尚未同步或已重置（下次将执行全量同步）"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "\(formatter.string(from: date)) (增量同步模式)"
    }
    
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
                        
                        Text("当前 App 已连接到您自建的 PostgreSQL + PostgREST 后端服务。已开启增量同步 (Delta Sync) 与软删除 (Soft Delete)，节省流量并实现毫秒级自动同步。")
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                            .lineSpacing(4)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("网络与协同通道") {
                    HStack {
                        Label("网络状态", systemImage: "network")
                            .font(.subheadline)
                        Spacer()
                        if NetworkMonitor.shared.isConnected {
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 8, height: 8)
                                Text(NetworkMonitor.shared.isCellular ? "蜂窝数据在线" : "WiFi 已连通")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Circle().fill(Color.red).frame(width: 8, height: 8)
                                Text("离线模式")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    HStack {
                        Label("协同协议", systemImage: "bolt.horizontal.fill")
                            .font(.subheadline)
                        Spacer()
                        if RealtimeManager.shared.isConnected {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill").foregroundColor(.orange).font(.caption2)
                                Text("WebSocket 实时协同在线")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(.blue).font(.caption2)
                                Text("智能自适应心跳轮询")
                                    .font(.caption)
                                    .foregroundColor(Color(.secondaryLabel))
                            }
                        }
                    }
                    
                    if SyncOutbox.shared.pendingCount > 0 {
                        HStack {
                            Label("离线待发队列", systemImage: "tray.and.arrow.up.fill")
                                .font(.subheadline)
                            Spacer()
                            Text("\(SyncOutbox.shared.pendingCount) 条未投递操作")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Button {
                            Task {
                                _ = await SyncOutbox.shared.flush(url: appState.supabaseURL, key: appState.supabaseKey)
                                appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
                            }
                        } label: {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("立即重新投递离线发件箱")
                            }
                            .foregroundColor(Color(hex: "#FF5E36"))
                            .font(.subheadline)
                        }
                    }
                }
                
                Section("同步状态与游标") {
                    HStack {
                        Text("最后同步时间")
                            .font(.subheadline)
                        Spacer()
                        Text(lastSyncText)
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                    }
                    
                    Button {
                        forceFullSync()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("重置游标并执行强制全量同步")
                        }
                        .foregroundColor(Color(hex: "#FF5E36"))
                        .font(.subheadline)
                    }
                    .disabled(isTesting)
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
                            Text(isTesting ? "正在连通云端并同步..." : "测试连接并立即同步")
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
                    testStatus = "✅ 同步成功！已与云端数据库完成增量双向同步。"
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
    
    private func forceFullSync() {
        isTesting = true
        testStatus = ""
        appState.resetSyncCursor()
        
        Task {
            do {
                _ = try await SupabaseManager.shared.fetchMembers(url: url, key: key)
                await SyncEngine.shared.syncDown(context: modelContext, appState: appState, forceFullSync: true)
                await MainActor.run {
                    testSuccess = true
                    testStatus = "✅ 全量同步成功！已重新拉取云端完整数据快照并重置同步游标。"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testSuccess = false
                    testStatus = "❌ 全量同步失败: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}
