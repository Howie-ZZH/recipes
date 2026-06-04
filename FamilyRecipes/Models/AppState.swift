import SwiftUI
import Combine

@Observable
@MainActor
final class AppState {
    var currentMember: FamilyMember?
    
    // Cloud Settings Properties
    var isCloudSyncEnabled: Bool = true // Force true since we are pure cloud native!
    var supabaseURL: String = "https://sbghojlespqzdelxrarh.supabase.co"
    var supabaseKey: String = "sb_publishable_dsiukZ2DCrqIB6FzNZ7-Lw_h1Kae7J8"
    
    // Main In-Memory Data Repositories
    var members: [FamilyMember] = []
    var dishes: [Dish] = []
    var orders: [MealOrder] = []
    
    // UI Feedback States
    var isLoading: Bool = false
    var networkError: String = ""
    
    init() {
        // Load settings from UserDefaults if they exist
        self.supabaseURL = UserDefaults.standard.string(forKey: "supabaseUrl") ?? "https://sbghojlespqzdelxrarh.supabase.co"
        self.supabaseKey = UserDefaults.standard.string(forKey: "supabaseKey") ?? "sb_publishable_dsiukZ2DCrqIB6FzNZ7-Lw_h1Kae7J8"
    }
    
    // MARK: - Selected Member Context
    
    private var activeMemberIdString: String {
        get {
            UserDefaults.standard.string(forKey: "activeMemberId") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "activeMemberId")
        }
    }
    
    func loadActiveMember() {
        let savedId = activeMemberIdString
        guard !savedId.isEmpty, let uuid = UUID(uuidString: savedId) else { return }
        
        if let found = members.first(where: { $0.id == uuid }) {
            self.currentMember = found
        }
    }
    
    func setActiveMember(_ member: FamilyMember?) {
        self.currentMember = member
        if let member = member {
            activeMemberIdString = member.id.uuidString
        } else {
            activeMemberIdString = ""
        }
    }
    
    // MARK: - Cloud Configurations
    
    func setSupabaseURL(_ url: String) {
        self.supabaseURL = url
        UserDefaults.standard.set(url, forKey: "supabaseUrl")
    }
    
    func setSupabaseKey(_ key: String) {
        self.supabaseKey = key
        UserDefaults.standard.set(key, forKey: "supabaseKey")
    }
    
    // MARK: - Cloud Sync Core Actions
    
    // Fetch all records in parallel and resolve dependencies in memory
    func fetchAllData() async {
        guard !supabaseURL.isEmpty, !supabaseKey.isEmpty else { return }
        isLoading = true
        networkError = ""
        
        do {
            async let fetchedMembers = SupabaseManager.shared.fetchMembers(url: supabaseURL, key: supabaseKey)
            async let fetchedDishes = SupabaseManager.shared.fetchDishes(url: supabaseURL, key: supabaseKey)
            async let fetchedOrders = SupabaseManager.shared.fetchOrders(url: supabaseURL, key: supabaseKey)
            
            // Resolve parallel fetches
            let resolvedMembers = try await fetchedMembers
            let resolvedDishes = try await fetchedDishes
            let resolvedOrders = try await fetchedOrders
            
            // Update in-memory arrays on MainActor
            self.members = resolvedMembers.sorted(by: { $0.name < $1.name })
            self.dishes = resolvedDishes.sorted(by: { $0.name < $1.name })
            
            // Resolve object graphs for MealOrders
            var tempOrders: [MealOrder] = []
            for order in resolvedOrders {
                // Find matching member
                if let matchedMember = self.members.first(where: { $0.id == order.memberId }) {
                    order.member = matchedMember
                }
                
                // Find matching dish if it exists
                if let dishId = order.dishId, let matchedDish = self.dishes.first(where: { $0.id == dishId }) {
                    order.dish = matchedDish
                }
                
                tempOrders.append(order)
            }
            
            self.orders = tempOrders
            
            // Reload active profile context if needed
            loadActiveMember()
            isLoading = false
        } catch {
            isLoading = false
            self.networkError = "网络请求失败，请稍后重试：\(error.localizedDescription)"
            print("Failed to fetch initial Supabase data: \(error)")
        }
    }
    
    // MARK: - Member Mutation Operations
    
    func addMember(name: String, emoji: String, role: String) async {
        let newMember = FamilyMember(name: name, emoji: emoji, role: role)
        do {
            try await SupabaseManager.shared.upsertMember(newMember, url: supabaseURL, key: supabaseKey)
            self.members.append(newMember)
            self.members.sort(by: { $0.name < $1.name })
        } catch {
            self.networkError = "无法添加家庭成员：\(error.localizedDescription)"
        }
    }
    
    func updateMember(_ member: FamilyMember) async {
        do {
            try await SupabaseManager.shared.upsertMember(member, url: supabaseURL, key: supabaseKey)
            if let index = self.members.firstIndex(where: { $0.id == member.id }) {
                self.members[index] = member
            }
        } catch {
            self.networkError = "无法更新家庭成员：\(error.localizedDescription)"
        }
    }
    
    func deleteMember(id: UUID) async {
        do {
            try await SupabaseManager.shared.deleteMember(id: id, url: supabaseURL, key: supabaseKey)
            self.members.removeAll(where: { $0.id == id })
            if currentMember?.id == id {
                setActiveMember(nil)
            }
        } catch {
            self.networkError = "无法删除家庭成员：\(error.localizedDescription)"
        }
    }
    
    // MARK: - Dish Mutation Operations
    
    func addDish(_ dish: Dish) async {
        do {
            try await SupabaseManager.shared.upsertDish(dish, url: supabaseURL, key: supabaseKey)
            self.dishes.append(dish)
            self.dishes.sort(by: { $0.name < $1.name })
        } catch {
            self.networkError = "无法添加菜品：\(error.localizedDescription)"
        }
    }
    
    func updateDish(_ dish: Dish) async {
        do {
            try await SupabaseManager.shared.upsertDish(dish, url: supabaseURL, key: supabaseKey)
            if let index = self.dishes.firstIndex(where: { $0.id == dish.id }) {
                self.dishes[index] = dish
            }
        } catch {
            self.networkError = "无法更新菜品：\(error.localizedDescription)"
        }
    }
    
    func deleteDish(id: UUID) async {
        do {
            try await SupabaseManager.shared.deleteDish(id: id, url: supabaseURL, key: supabaseKey)
            self.dishes.removeAll(where: { $0.id == id })
            // Clean up related local orders in memory
            self.orders.removeAll(where: { $0.dishId == id })
        } catch {
            self.networkError = "无法删除菜品：\(error.localizedDescription)"
        }
    }
    
    // MARK: - Order Mutation Operations
    
    func createOrder(member: FamilyMember, dish: Dish, note: String) async {
        let order = MealOrder(member: member, dish: dish, note: note)
        do {
            try await SupabaseManager.shared.upsertOrder(order, url: supabaseURL, key: supabaseKey)
            self.orders.insert(order, at: 0) // Newest order first
        } catch {
            self.networkError = "无法提交点餐订单：\(error.localizedDescription)"
        }
    }
    
    func fulfillOrder(_ order: MealOrder) async {
        order.isFulfilled = true
        do {
            try await SupabaseManager.shared.upsertOrder(order, url: supabaseURL, key: supabaseKey)
            if let index = self.orders.firstIndex(where: { $0.id == order.id }) {
                self.orders[index] = order
            }
        } catch {
            order.isFulfilled = false // Rollback
            self.networkError = "无法标记点餐完成：\(error.localizedDescription)"
        }
    }
    
    func deleteOrder(id: UUID) async {
        do {
            try await SupabaseManager.shared.deleteOrder(id: id, url: supabaseURL, key: supabaseKey)
            self.orders.removeAll(where: { $0.id == id })
        } catch {
            self.networkError = "无法删除点餐记录：\(error.localizedDescription)"
        }
    }
}
