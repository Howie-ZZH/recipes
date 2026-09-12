import Foundation
import SwiftData

struct OutboxMutation: Codable, Identifiable, Equatable {
    var id: UUID
    var entityId: UUID
    var entityType: EntityType
    var actionType: ActionType
    var payload: Data
    var createdAt: Date
    var retryCount: Int
    
    enum EntityType: String, Codable {
        case member
        case dish
        case order
        case diary
    }
    
    enum ActionType: String, Codable {
        case upsert
        case softDelete
    }
    
    init(
        id: UUID = UUID(),
        entityId: UUID,
        entityType: EntityType,
        actionType: ActionType,
        payload: Data,
        createdAt: Date = Date(),
        retryCount: Int = 0
    ) {
        self.id = id
        self.entityId = entityId
        self.entityType = entityType
        self.actionType = actionType
        self.payload = payload
        self.createdAt = createdAt
        self.retryCount = retryCount
    }
}

@Observable
@MainActor
final class SyncOutbox {
    static let shared = SyncOutbox()
    
    private let storageKey = "sync_outbox_mutations"
    var pendingMutations: [OutboxMutation] = []
    
    var pendingCount: Int {
        pendingMutations.count
    }
    
    var isFlushing: Bool = false
    
    init() {
        loadFromStorage()
    }
    
    func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            self.pendingMutations = []
            return
        }
        let decoder = JSONDecoder()
        if let items = try? decoder.decode([OutboxMutation].self, from: data) {
            self.pendingMutations = items
        } else {
            self.pendingMutations = []
        }
    }
    
    private func saveToStorage() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(pendingMutations) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    func enqueue(_ mutation: OutboxMutation) {
        // If an upsert/delete already exists for the same entity, replace or update it
        if let index = pendingMutations.firstIndex(where: { $0.entityId == mutation.entityId }) {
            pendingMutations[index] = mutation
        } else {
            pendingMutations.append(mutation)
        }
        saveToStorage()
    }
    
    func remove(id: UUID) {
        pendingMutations.removeAll(where: { $0.id == id })
        saveToStorage()
    }
    
    func clear() {
        pendingMutations.removeAll()
        saveToStorage()
    }
    
    // Flush pending mutations to remote server
    func flush(url: String, key: String) async -> Int {
        guard !isFlushing else { return 0 }
        guard !url.isEmpty else { return 0 }
        guard !pendingMutations.isEmpty else { return 0 }
        
        isFlushing = true
        defer { isFlushing = false }
        
        var succeededIds = Set<UUID>()
        
        for mutation in pendingMutations {
            do {
                try await executeMutation(mutation, url: url, key: key)
                succeededIds.insert(mutation.id)
            } catch {
                print("[SyncOutbox] Failed to deliver mutation \(mutation.id): \(error)")
                // Stop sequential flush on network failure to preserve FIFO consistency
                break
            }
        }
        
        pendingMutations.removeAll(where: { succeededIds.contains($0.id) })
        saveToStorage()
        
        return succeededIds.count
    }
    
    private func executeMutation(_ mutation: OutboxMutation, url: String, key: String) async throws {
        let decoder = SupabaseManager.makeDecoder()
        
        switch (mutation.entityType, mutation.actionType) {
        case (.member, .upsert):
            let dto = try decoder.decode(MemberDTO.self, from: mutation.payload)
            try await SupabaseManager.shared.upsertMember(dto, url: url, key: key)
        case (.member, .softDelete):
            do {
                try await SupabaseManager.shared.softDeleteMember(id: mutation.entityId, url: url, key: key)
            } catch {
                try await SupabaseManager.shared.deleteMember(id: mutation.entityId, url: url, key: key)
            }
            
        case (.dish, .upsert):
            let dto = try decoder.decode(DishDTO.self, from: mutation.payload)
            try await SupabaseManager.shared.upsertDish(dto, url: url, key: key)
        case (.dish, .softDelete):
            do {
                try await SupabaseManager.shared.softDeleteDish(id: mutation.entityId, url: url, key: key)
            } catch {
                try await SupabaseManager.shared.deleteDish(id: mutation.entityId, url: url, key: key)
            }
            
        case (.order, .upsert):
            let dto = try decoder.decode(OrderDTO.self, from: mutation.payload)
            try await SupabaseManager.shared.upsertOrder(dto, url: url, key: key)
        case (.order, .softDelete):
            do {
                try await SupabaseManager.shared.softDeleteOrder(id: mutation.entityId, url: url, key: key)
            } catch {
                try await SupabaseManager.shared.deleteOrder(id: mutation.entityId, url: url, key: key)
            }
            
        case (.diary, .upsert):
            let dto = try decoder.decode(DiaryDTO.self, from: mutation.payload)
            try await SupabaseManager.shared.upsertDiary(dto, url: url, key: key)
        case (.diary, .softDelete):
            do {
                try await SupabaseManager.shared.softDeleteDiary(id: mutation.entityId, url: url, key: key)
            } catch {
                try await SupabaseManager.shared.deleteDiary(id: mutation.entityId, url: url, key: key)
            }
        }
    }
}
