import SwiftData
import Foundation

@MainActor
final class SyncEngine {
    static let shared = SyncEngine()
    private init() {}
    
    func syncDown(context: ModelContext, appState: AppState) async {
        guard !appState.supabaseURL.isEmpty else { return }
        
        appState.isSyncing = true
        appState.networkError = ""
        
        do {
            async let fetchedMembers = SupabaseManager.shared.fetchMembers(url: appState.supabaseURL, key: appState.supabaseKey)
            async let fetchedDishes = SupabaseManager.shared.fetchDishes(url: appState.supabaseURL, key: appState.supabaseKey)
            async let fetchedOrders = SupabaseManager.shared.fetchOrders(url: appState.supabaseURL, key: appState.supabaseKey)
            async let fetchedDiaries = SupabaseManager.shared.fetchDiaries(url: appState.supabaseURL, key: appState.supabaseKey)
            
            let remoteMembers = try await fetchedMembers
            let remoteDishes = try await fetchedDishes
            let remoteOrders = try await fetchedOrders
            let remoteDiaries = try await fetchedDiaries
            
            // 1. Sync Members
            for rMember in remoteMembers {
                let targetId = rMember.id
                let descriptor = FetchDescriptor<FamilyMember>(predicate: #Predicate { $0.id == targetId })
                if let localMember = try? context.fetch(descriptor).first {
                    if rMember.updatedAt > localMember.updatedAt {
                        localMember.update(from: rMember)
                    }
                } else {
                    let newMember = FamilyMember(id: rMember.id, name: rMember.name, emoji: rMember.emoji, role: rMember.role, updatedAt: rMember.updatedAt)
                    context.insert(newMember)
                }
            }
            
            // 2. Sync Dishes
            for rDish in remoteDishes {
                let targetId = rDish.id
                let descriptor = FetchDescriptor<Dish>(predicate: #Predicate { $0.id == targetId })
                if let localDish = try? context.fetch(descriptor).first {
                    if rDish.updatedAt > localDish.updatedAt {
                        localDish.update(from: rDish)
                    }
                } else {
                    let newDish = Dish(id: rDish.id, name: rDish.name, category: rDish.category, tags: rDish.tags, emoji: rDish.emoji, dishDescription: rDish.dishDescription, ingredients: rDish.ingredients, cookNote: rDish.cookNote, isFavorite: rDish.isFavorite, imageData: nil, updatedAt: rDish.updatedAt)
                    newDish.update(from: rDish)
                    context.insert(newDish)
                }
            }
            
            // 3. Sync Orders
            for rOrder in remoteOrders {
                let targetId = rOrder.id
                let descriptor = FetchDescriptor<MealOrder>(predicate: #Predicate { $0.id == targetId })
                
                var orderToUpdate: MealOrder?
                if let localOrder = try? context.fetch(descriptor).first {
                    if rOrder.updatedAt > localOrder.updatedAt {
                        localOrder.update(from: rOrder)
                        orderToUpdate = localOrder
                    }
                } else {
                    let newOrder = MealOrder(id: rOrder.id, note: rOrder.note, orderDate: rOrder.orderDate, isFulfilled: rOrder.isFulfilled, updatedAt: rOrder.updatedAt)
                    context.insert(newOrder)
                    orderToUpdate = newOrder
                }
                
                if let order = orderToUpdate {
                    let mId = rOrder.memberId
                    let mDescriptor = FetchDescriptor<FamilyMember>(predicate: #Predicate { $0.id == mId })
                    if let member = try? context.fetch(mDescriptor).first {
                        order.member = member
                    }
                    if let dId = rOrder.dishId {
                        let dDescriptor = FetchDescriptor<Dish>(predicate: #Predicate { $0.id == dId })
                        if let dish = try? context.fetch(dDescriptor).first {
                            order.dish = dish
                        }
                    }
                }
            }
            
            // 4. Sync Diaries
            for rDiary in remoteDiaries {
                let targetId = rDiary.id
                let descriptor = FetchDescriptor<FoodDiary>(predicate: #Predicate { $0.id == targetId })
                
                var diaryToUpdate: FoodDiary?
                if let localDiary = try? context.fetch(descriptor).first {
                    if rDiary.updatedAt > localDiary.updatedAt {
                        localDiary.update(from: rDiary)
                        diaryToUpdate = localDiary
                    }
                } else {
                    let newDiary = FoodDiary(id: rDiary.id, diaryDate: Date(), rating: rDiary.rating, comment: rDiary.comment, imageData: nil, updatedAt: rDiary.updatedAt)
                    newDiary.update(from: rDiary)
                    context.insert(newDiary)
                    diaryToUpdate = newDiary
                }
                
                if let diary = diaryToUpdate {
                    let mId = rDiary.memberId
                    let mDescriptor = FetchDescriptor<FamilyMember>(predicate: #Predicate { $0.id == mId })
                    if let member = try? context.fetch(mDescriptor).first {
                        diary.member = member
                    }
                    let dId = rDiary.dishId
                    let dDescriptor = FetchDescriptor<Dish>(predicate: #Predicate { $0.id == dId })
                    if let dish = try? context.fetch(dDescriptor).first {
                        diary.dish = dish
                    }
                }
            }
            
            try? context.save()
            appState.isSyncing = false
            
        } catch {
            appState.networkError = "网络同步失败：\(error.localizedDescription)"
            appState.isSyncing = false
            print("Failed to sync down: \(error)")
        }
    }
    
    // MARK: - Push Actions (Optimistic UI fallback)
    
    func push(_ member: FamilyMember, appState: AppState) {
        let dto = member.dto
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        Task {
            do {
                try await SupabaseManager.shared.upsertMember(dto, url: url, key: key)
            } catch {
                print("[SyncEngine] Failed to push member: \(error)")
            }
        }
    }
    
    func deleteMember(id: UUID, appState: AppState) {
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        Task {
            try? await SupabaseManager.shared.deleteMember(id: id, url: url, key: key)
        }
    }
    
    func push(_ dish: Dish, appState: AppState) {
        let dto = dish.dto
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        Task {
            do {
                try await SupabaseManager.shared.upsertDish(dto, url: url, key: key)
            } catch {
                print("[SyncEngine] Failed to push dish: \(error)")
            }
        }
    }
    
    func deleteDish(id: UUID, appState: AppState) {
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        Task {
            try? await SupabaseManager.shared.deleteDish(id: id, url: url, key: key)
        }
    }
    
    func push(_ order: MealOrder, appState: AppState) {
        let dto = order.dto
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        Task {
            do {
                try await SupabaseManager.shared.upsertOrder(dto, url: url, key: key)
            } catch {
                print("[SyncEngine] Failed to push order: \(error)")
            }
        }
    }
    
    func deleteOrder(id: UUID, appState: AppState) {
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        Task {
            try? await SupabaseManager.shared.deleteOrder(id: id, url: url, key: key)
        }
    }
    
    func push(_ diary: FoodDiary, appState: AppState) {
        let dto = diary.dto
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        Task {
            do {
                try await SupabaseManager.shared.upsertDiary(dto, url: url, key: key)
            } catch {
                print("[SyncEngine] Failed to push diary: \(error)")
            }
        }
    }
    
    func deleteDiary(id: UUID, appState: AppState) {
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        Task {
            try? await SupabaseManager.shared.deleteDiary(id: id, url: url, key: key)
        }
    }
}
