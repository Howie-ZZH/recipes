import SwiftData
import Foundation

@MainActor
final class SyncEngine {
    static let shared = SyncEngine()
    private init() {}
    
    private var activeSyncTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    
    // MARK: - Realtime & Polling Lifecycle
    
    func startRealtimeAndPolling(context: ModelContext, appState: AppState, interval: TimeInterval = 15) {
        stopRealtimeAndPolling()
        
        // 1. Hook up Network Status
        NetworkMonitor.shared.onStatusChange = { [weak self] isConnected in
            Task { @MainActor in
                if isConnected {
                    _ = await SyncOutbox.shared.flush(url: appState.supabaseURL, key: appState.supabaseKey)
                    appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
                    await self?.syncDown(context: context, appState: appState, isSilent: true)
                    RealtimeManager.shared.connect(url: appState.supabaseURL, key: appState.supabaseKey)
                } else {
                    RealtimeManager.shared.disconnect()
                    appState.isRealtimeConnected = false
                }
            }
        }
        
        // 2. Hook up Realtime WebSocket
        RealtimeManager.shared.onRemoteChange = { [weak self] in
            Task { @MainActor in
                await self?.syncDown(context: context, appState: appState, isSilent: true)
            }
        }
        
        if NetworkMonitor.shared.isConnected && !appState.supabaseURL.isEmpty {
            RealtimeManager.shared.connect(url: appState.supabaseURL, key: appState.supabaseKey)
        }
        
        // 3. Start Adaptive Poller as Fallback
        startForegroundPolling(context: context, appState: appState, interval: interval)
        
        // 4. Flush any pending mutations
        Task {
            if NetworkMonitor.shared.isConnected {
                _ = await SyncOutbox.shared.flush(url: appState.supabaseURL, key: appState.supabaseKey)
                appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
            }
        }
    }
    
    func stopRealtimeAndPolling() {
        stopForegroundPolling()
        RealtimeManager.shared.disconnect()
        NetworkMonitor.shared.onStatusChange = nil
        RealtimeManager.shared.onRemoteChange = nil
    }
    
    // MARK: - Foreground Polling
    
    func startForegroundPolling(context: ModelContext, appState: AppState, interval: TimeInterval = 15) {
        stopForegroundPolling()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { break }
                if NetworkMonitor.shared.isConnected {
                    await syncDown(context: context, appState: appState, isSilent: true)
                }
            }
        }
    }
    
    func stopForegroundPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    var isPolling: Bool {
        pollingTask != nil && !(pollingTask?.isCancelled ?? true)
    }
    
    // MARK: - Sync Down (Delta Sync & Full Snapshot Sync)
    
    func syncDown(
        context: ModelContext,
        appState: AppState,
        isSilent: Bool = false,
        forceFullSync: Bool = false
    ) async {
        if let existing = activeSyncTask {
            await existing.value
            return
        }
        
        let task = Task {
            await performSyncDown(
                context: context,
                appState: appState,
                isSilent: isSilent,
                forceFullSync: forceFullSync
            )
        }
        activeSyncTask = task
        await task.value
        activeSyncTask = nil
    }
    
    private func performSyncDown(
        context: ModelContext,
        appState: AppState,
        isSilent: Bool,
        forceFullSync: Bool
    ) async {
        guard !appState.supabaseURL.isEmpty else { return }
        guard NetworkMonitor.shared.isConnected else { return }
        
        if !isSilent {
            appState.isSyncing = true
            appState.networkError = ""
        }
        
        // Before pulling down, flush outbox if any mutations exist
        if SyncOutbox.shared.pendingCount > 0 {
            _ = await SyncOutbox.shared.flush(url: appState.supabaseURL, key: appState.supabaseKey)
            appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
        }
        
        let syncStartTime = Date()
        let isDeltaSync = !forceFullSync && appState.lastSyncTimestamp != nil
        let sinceDate = isDeltaSync ? appState.lastSyncTimestamp : nil
        
        do {
            async let fetchedMembers = SupabaseManager.shared.fetchMembers(url: appState.supabaseURL, key: appState.supabaseKey, since: sinceDate)
            async let fetchedDishes = SupabaseManager.shared.fetchDishes(url: appState.supabaseURL, key: appState.supabaseKey, since: sinceDate)
            async let fetchedOrders = SupabaseManager.shared.fetchOrders(url: appState.supabaseURL, key: appState.supabaseKey, since: sinceDate)
            async let fetchedDiaries = SupabaseManager.shared.fetchDiaries(url: appState.supabaseURL, key: appState.supabaseKey, since: sinceDate)
            
            let remoteMembers = try await fetchedMembers
            let remoteDishes = try await fetchedDishes
            let remoteOrders = try await fetchedOrders
            let remoteDiaries = try await fetchedDiaries
            
            if isDeltaSync {
                // --- INCREMENTAL (DELTA) MERGE STRATEGY ---
                applyDeltaMembers(remoteMembers, context: context, appState: appState)
                applyDeltaDishes(remoteDishes, context: context, appState: appState)
                applyDeltaOrders(remoteOrders, context: context, appState: appState)
                applyDeltaDiaries(remoteDiaries, context: context, appState: appState)
            } else {
                // --- FULL SNAPSHOT MERGE STRATEGY ---
                applyFullMembers(remoteMembers, context: context, appState: appState)
                applyFullDishes(remoteDishes, context: context, appState: appState)
                applyFullOrders(remoteOrders, context: context, appState: appState)
                applyFullDiaries(remoteDiaries, context: context, appState: appState)
            }
            
            // Validate active member ID still exists after sync
            let currentMemberIds = Set(((try? context.fetch(FetchDescriptor<FamilyMember>())) ?? []).map { $0.id })
            if let activeId = appState.activeMemberId, !currentMemberIds.contains(activeId) {
                appState.activeMemberId = nil
            }
            
            try? context.save()
            appState.lastSyncTimestamp = syncStartTime
            appState.isRealtimeConnected = RealtimeManager.shared.isConnected
            
            if !isSilent {
                appState.isSyncing = false
            }
            
        } catch {
            if !isSilent {
                appState.networkError = "网络同步失败：\(error.localizedDescription)"
                appState.isSyncing = false
            }
            print("[SyncEngine] Failed to sync down (silent=\(isSilent), delta=\(isDeltaSync)): \(error)")
        }
    }
    
    // MARK: - Delta Merge Handlers (Incremental)
    
    private func applyDeltaMembers(_ remoteMembers: [MemberDTO], context: ModelContext, appState: AppState) {
        for rMember in remoteMembers {
            let targetId = rMember.id
            let descriptor = FetchDescriptor<FamilyMember>(predicate: #Predicate { $0.id == targetId })
            let localMember = try? context.fetch(descriptor).first
            
            if rMember.isDeleted {
                if let existing = localMember {
                    context.delete(existing)
                }
            } else {
                if let existing = localMember {
                    if rMember.updatedAt >= existing.updatedAt {
                        existing.update(from: rMember)
                    }
                } else {
                    let newMember = FamilyMember(id: rMember.id, name: rMember.name, emoji: rMember.emoji, role: rMember.role, updatedAt: rMember.updatedAt)
                    context.insert(newMember)
                }
            }
        }
    }
    
    private func applyDeltaDishes(_ remoteDishes: [DishDTO], context: ModelContext, appState: AppState) {
        for rDish in remoteDishes {
            let targetId = rDish.id
            let descriptor = FetchDescriptor<Dish>(predicate: #Predicate { $0.id == targetId })
            let localDish = try? context.fetch(descriptor).first
            
            if rDish.isDeleted {
                if let existing = localDish {
                    context.delete(existing)
                }
            } else {
                if let existing = localDish {
                    if rDish.updatedAt >= existing.updatedAt {
                        existing.update(from: rDish)
                    }
                } else {
                    let newDish = Dish(id: rDish.id, name: rDish.name, category: rDish.category, tags: rDish.tags, emoji: rDish.emoji, dishDescription: rDish.dishDescription, ingredients: rDish.ingredients, cookNote: rDish.cookNote, isFavorite: rDish.isFavorite, imageData: nil, updatedAt: rDish.updatedAt)
                    newDish.update(from: rDish)
                    context.insert(newDish)
                }
            }
        }
    }
    
    private func applyDeltaOrders(_ remoteOrders: [OrderDTO], context: ModelContext, appState: AppState) {
        for rOrder in remoteOrders {
            let targetId = rOrder.id
            let descriptor = FetchDescriptor<MealOrder>(predicate: #Predicate { $0.id == targetId })
            let localOrder = try? context.fetch(descriptor).first
            
            if rOrder.isDeleted {
                if let existing = localOrder {
                    context.delete(existing)
                }
            } else {
                var orderToUpdate: MealOrder?
                if let existing = localOrder {
                    if rOrder.updatedAt >= existing.updatedAt {
                        existing.update(from: rOrder)
                        orderToUpdate = existing
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
        }
    }
    
    private func applyDeltaDiaries(_ remoteDiaries: [DiaryDTO], context: ModelContext, appState: AppState) {
        for rDiary in remoteDiaries {
            let targetId = rDiary.id
            let descriptor = FetchDescriptor<FoodDiary>(predicate: #Predicate { $0.id == targetId })
            let localDiary = try? context.fetch(descriptor).first
            
            if rDiary.isDeleted {
                if let existing = localDiary {
                    context.delete(existing)
                }
            } else {
                var diaryToUpdate: FoodDiary?
                if let existing = localDiary {
                    if rDiary.updatedAt >= existing.updatedAt {
                        existing.update(from: rDiary)
                        diaryToUpdate = existing
                    }
                } else {
                    let initialDate = rDiary.parsedDiaryDate ?? Date()
                    let newDiary = FoodDiary(id: rDiary.id, diaryDate: initialDate, rating: rDiary.rating, comment: rDiary.comment, imageData: nil, updatedAt: rDiary.updatedAt)
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
        }
    }
    
    // MARK: - Full Snapshot Merge Handlers
    
    private func applyFullMembers(_ remoteMembers: [MemberDTO], context: ModelContext, appState: AppState) {
        let activeRemotes = remoteMembers.filter { !$0.isDeleted }
        if activeRemotes.isEmpty {
            let localMembers = (try? context.fetch(FetchDescriptor<FamilyMember>())) ?? []
            if localMembers.isEmpty {
                for member in SampleData.mockMembers {
                    context.insert(member)
                    push(member, appState: appState)
                }
            } else {
                for member in localMembers {
                    push(member, appState: appState)
                }
            }
        } else {
            let remoteMemberIds = Set(activeRemotes.map { $0.id })
            if let localMembers = try? context.fetch(FetchDescriptor<FamilyMember>()) {
                for localMember in localMembers {
                    if !remoteMemberIds.contains(localMember.id) {
                        context.delete(localMember)
                    }
                }
            }
            for rMember in activeRemotes {
                let targetId = rMember.id
                let descriptor = FetchDescriptor<FamilyMember>(predicate: #Predicate { $0.id == targetId })
                if let localMember = try? context.fetch(descriptor).first {
                    if rMember.updatedAt >= localMember.updatedAt {
                        localMember.update(from: rMember)
                    }
                } else {
                    let newMember = FamilyMember(id: rMember.id, name: rMember.name, emoji: rMember.emoji, role: rMember.role, updatedAt: rMember.updatedAt)
                    context.insert(newMember)
                }
            }
        }
    }
    
    private func applyFullDishes(_ remoteDishes: [DishDTO], context: ModelContext, appState: AppState) {
        let activeRemotes = remoteDishes.filter { !$0.isDeleted }
        if activeRemotes.isEmpty {
            let localDishes = (try? context.fetch(FetchDescriptor<Dish>())) ?? []
            if localDishes.isEmpty {
                for dish in SampleData.mockDishes {
                    context.insert(dish)
                    push(dish, appState: appState)
                }
            } else {
                for dish in localDishes {
                    push(dish, appState: appState)
                }
            }
        } else {
            let remoteDishIds = Set(activeRemotes.map { $0.id })
            if let localDishes = try? context.fetch(FetchDescriptor<Dish>()) {
                for localDish in localDishes {
                    if !remoteDishIds.contains(localDish.id) {
                        context.delete(localDish)
                    }
                }
            }
            for rDish in activeRemotes {
                let targetId = rDish.id
                let descriptor = FetchDescriptor<Dish>(predicate: #Predicate { $0.id == targetId })
                if let localDish = try? context.fetch(descriptor).first {
                    if rDish.updatedAt >= localDish.updatedAt {
                        localDish.update(from: rDish)
                    }
                } else {
                    let newDish = Dish(id: rDish.id, name: rDish.name, category: rDish.category, tags: rDish.tags, emoji: rDish.emoji, dishDescription: rDish.dishDescription, ingredients: rDish.ingredients, cookNote: rDish.cookNote, isFavorite: rDish.isFavorite, imageData: nil, updatedAt: rDish.updatedAt)
                    newDish.update(from: rDish)
                    context.insert(newDish)
                }
            }
        }
    }
    
    private func applyFullOrders(_ remoteOrders: [OrderDTO], context: ModelContext, appState: AppState) {
        let activeRemotes = remoteOrders.filter { !$0.isDeleted }
        if activeRemotes.isEmpty {
            let localOrders = (try? context.fetch(FetchDescriptor<MealOrder>())) ?? []
            for order in localOrders {
                push(order, appState: appState)
            }
        } else {
            let remoteOrderIds = Set(activeRemotes.map { $0.id })
            if let localOrders = try? context.fetch(FetchDescriptor<MealOrder>()) {
                for localOrder in localOrders {
                    if !remoteOrderIds.contains(localOrder.id) {
                        context.delete(localOrder)
                    }
                }
            }
            for rOrder in activeRemotes {
                let targetId = rOrder.id
                let descriptor = FetchDescriptor<MealOrder>(predicate: #Predicate { $0.id == targetId })
                
                var orderToUpdate: MealOrder?
                if let localOrder = try? context.fetch(descriptor).first {
                    if rOrder.updatedAt >= localOrder.updatedAt {
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
        }
    }
    
    private func applyFullDiaries(_ remoteDiaries: [DiaryDTO], context: ModelContext, appState: AppState) {
        let activeRemotes = remoteDiaries.filter { !$0.isDeleted }
        if activeRemotes.isEmpty {
            let localDiaries = (try? context.fetch(FetchDescriptor<FoodDiary>())) ?? []
            for diary in localDiaries {
                push(diary, appState: appState)
            }
        } else {
            let remoteDiaryIds = Set(activeRemotes.map { $0.id })
            if let localDiaries = try? context.fetch(FetchDescriptor<FoodDiary>()) {
                for localDiary in localDiaries {
                    if !remoteDiaryIds.contains(localDiary.id) {
                        context.delete(localDiary)
                    }
                }
            }
            for rDiary in activeRemotes {
                let targetId = rDiary.id
                let descriptor = FetchDescriptor<FoodDiary>(predicate: #Predicate { $0.id == targetId })
                
                var diaryToUpdate: FoodDiary?
                if let localDiary = try? context.fetch(descriptor).first {
                    if rDiary.updatedAt >= localDiary.updatedAt {
                        localDiary.update(from: rDiary)
                        diaryToUpdate = localDiary
                    }
                } else {
                    let initialDate = rDiary.parsedDiaryDate ?? Date()
                    let newDiary = FoodDiary(id: rDiary.id, diaryDate: initialDate, rating: rDiary.rating, comment: rDiary.comment, imageData: nil, updatedAt: rDiary.updatedAt)
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
        }
    }
    
    // MARK: - Push & Soft Delete Actions (with Outbox Fallback)
    
    func push(_ member: FamilyMember, appState: AppState) {
        let dto = member.dto
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let payload = try? encoder.encode(dto) else { return }
        
        if !NetworkMonitor.shared.isConnected || url.isEmpty {
            let mutation = OutboxMutation(entityId: dto.id, entityType: .member, actionType: .upsert, payload: payload)
            SyncOutbox.shared.enqueue(mutation)
            appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
            return
        }
        
        Task {
            do {
                try await SupabaseManager.shared.upsertMember(dto, url: url, key: key)
            } catch {
                print("[SyncEngine] Network error on push member, enqueuing to outbox: \(error)")
                let mutation = OutboxMutation(entityId: dto.id, entityType: .member, actionType: .upsert, payload: payload)
                SyncOutbox.shared.enqueue(mutation)
                appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
            }
        }
    }
    
    func deleteMember(id: UUID, appState: AppState) {
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        
        if !NetworkMonitor.shared.isConnected || url.isEmpty {
            let mutation = OutboxMutation(entityId: id, entityType: .member, actionType: .softDelete, payload: Data())
            SyncOutbox.shared.enqueue(mutation)
            appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
            return
        }
        
        Task {
            do {
                try await SupabaseManager.shared.softDeleteMember(id: id, url: url, key: key)
            } catch {
                do {
                    try await SupabaseManager.shared.deleteMember(id: id, url: url, key: key)
                } catch {
                    print("[SyncEngine] Network error on delete member, enqueuing to outbox: \(error)")
                    let mutation = OutboxMutation(entityId: id, entityType: .member, actionType: .softDelete, payload: Data())
                    SyncOutbox.shared.enqueue(mutation)
                    appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
                }
            }
        }
    }
    
    func push(_ dish: Dish, appState: AppState) {
        let dto = dish.dto
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let payload = try? encoder.encode(dto) else { return }
        
        if !NetworkMonitor.shared.isConnected || url.isEmpty {
            let mutation = OutboxMutation(entityId: dto.id, entityType: .dish, actionType: .upsert, payload: payload)
            SyncOutbox.shared.enqueue(mutation)
            appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
            return
        }
        
        Task {
            do {
                try await SupabaseManager.shared.upsertDish(dto, url: url, key: key)
            } catch {
                print("[SyncEngine] Network error on push dish, enqueuing to outbox: \(error)")
                let mutation = OutboxMutation(entityId: dto.id, entityType: .dish, actionType: .upsert, payload: payload)
                SyncOutbox.shared.enqueue(mutation)
                appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
            }
        }
    }
    
    func deleteDish(id: UUID, appState: AppState) {
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        
        if !NetworkMonitor.shared.isConnected || url.isEmpty {
            let mutation = OutboxMutation(entityId: id, entityType: .dish, actionType: .softDelete, payload: Data())
            SyncOutbox.shared.enqueue(mutation)
            appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
            return
        }
        
        Task {
            do {
                try await SupabaseManager.shared.softDeleteDish(id: id, url: url, key: key)
            } catch {
                do {
                    try await SupabaseManager.shared.deleteDish(id: id, url: url, key: key)
                } catch {
                    print("[SyncEngine] Network error on delete dish, enqueuing to outbox: \(error)")
                    let mutation = OutboxMutation(entityId: id, entityType: .dish, actionType: .softDelete, payload: Data())
                    SyncOutbox.shared.enqueue(mutation)
                    appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
                }
            }
        }
    }
    
    func push(_ order: MealOrder, appState: AppState) {
        let dto = order.dto
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let payload = try? encoder.encode(dto) else { return }
        
        if !NetworkMonitor.shared.isConnected || url.isEmpty {
            let mutation = OutboxMutation(entityId: dto.id, entityType: .order, actionType: .upsert, payload: payload)
            SyncOutbox.shared.enqueue(mutation)
            appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
            return
        }
        
        Task {
            do {
                try await SupabaseManager.shared.upsertOrder(dto, url: url, key: key)
            } catch {
                print("[SyncEngine] Network error on push order, enqueuing to outbox: \(error)")
                let mutation = OutboxMutation(entityId: dto.id, entityType: .order, actionType: .upsert, payload: payload)
                SyncOutbox.shared.enqueue(mutation)
                appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
            }
        }
    }
    
    func deleteOrder(id: UUID, appState: AppState) {
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        
        if !NetworkMonitor.shared.isConnected || url.isEmpty {
            let mutation = OutboxMutation(entityId: id, entityType: .order, actionType: .softDelete, payload: Data())
            SyncOutbox.shared.enqueue(mutation)
            appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
            return
        }
        
        Task {
            do {
                try await SupabaseManager.shared.softDeleteOrder(id: id, url: url, key: key)
            } catch {
                do {
                    try await SupabaseManager.shared.deleteOrder(id: id, url: url, key: key)
                } catch {
                    print("[SyncEngine] Network error on delete order, enqueuing to outbox: \(error)")
                    let mutation = OutboxMutation(entityId: id, entityType: .order, actionType: .softDelete, payload: Data())
                    SyncOutbox.shared.enqueue(mutation)
                    appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
                }
            }
        }
    }
    
    func push(_ diary: FoodDiary, appState: AppState) {
        let dto = diary.dto
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let payload = try? encoder.encode(dto) else { return }
        
        if !NetworkMonitor.shared.isConnected || url.isEmpty {
            let mutation = OutboxMutation(entityId: dto.id, entityType: .diary, actionType: .upsert, payload: payload)
            SyncOutbox.shared.enqueue(mutation)
            appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
            return
        }
        
        Task {
            do {
                try await SupabaseManager.shared.upsertDiary(dto, url: url, key: key)
            } catch {
                print("[SyncEngine] Network error on push diary, enqueuing to outbox: \(error)")
                let mutation = OutboxMutation(entityId: dto.id, entityType: .diary, actionType: .upsert, payload: payload)
                SyncOutbox.shared.enqueue(mutation)
                appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
            }
        }
    }
    
    func deleteDiary(id: UUID, appState: AppState) {
        let url = appState.supabaseURL
        let key = appState.supabaseKey
        
        if !NetworkMonitor.shared.isConnected || url.isEmpty {
            let mutation = OutboxMutation(entityId: id, entityType: .diary, actionType: .softDelete, payload: Data())
            SyncOutbox.shared.enqueue(mutation)
            appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
            return
        }
        
        Task {
            do {
                try await SupabaseManager.shared.softDeleteDiary(id: id, url: url, key: key)
            } catch {
                do {
                    try await SupabaseManager.shared.deleteDiary(id: id, url: url, key: key)
                } catch {
                    print("[SyncEngine] Network error on delete diary, enqueuing to outbox: \(error)")
                    let mutation = OutboxMutation(entityId: id, entityType: .diary, actionType: .softDelete, payload: Data())
                    SyncOutbox.shared.enqueue(mutation)
                    appState.pendingOutboxCount = SyncOutbox.shared.pendingCount
                }
            }
        }
    }
}
