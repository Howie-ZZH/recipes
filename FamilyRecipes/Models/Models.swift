import Foundation
import Observation

@Observable
final class FamilyMember: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var emoji: String
    var role: String // "Cook" (掌勺人) 或 "Member" (普通家庭成员)
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
        case role
    }
    
    init(id: UUID = UUID(), name: String, emoji: String, role: String = "Member") {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.role = role
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        emoji = try container.decode(String.self, forKey: .emoji)
        role = try container.decode(String.self, forKey: .role)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(role, forKey: .role)
    }
    
    static func == (lhs: FamilyMember, rhs: FamilyMember) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Observable
final class Dish: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var category: String // "荤菜", "素菜", "汤羹", "主食", "甜品/其他"
    var tags: [String] // ["辣", "清淡", "高蛋白", "快手菜"]
    var emoji: String // 用 Emoji 作为菜名图标
    var dishDescription: String
    var ingredients: [String] // 食材原料列表，用于自动生成买菜清单
    var cookNote: String
    var isFavorite: Bool
    var imageData: Data?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case tags
        case emoji
        case dishDescription = "dish_description"
        case ingredients
        case cookNote = "cook_note"
        case isFavorite = "is_favorite"
        case imageBase64 = "image_base64"
    }
    
    init(id: UUID = UUID(), name: String, category: String, tags: [String] = [], emoji: String, dishDescription: String = "", ingredients: [String] = [], cookNote: String = "", isFavorite: Bool = false, imageData: Data? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.tags = tags
        self.emoji = emoji
        self.dishDescription = dishDescription
        self.ingredients = ingredients
        self.cookNote = cookNote
        self.isFavorite = isFavorite
        self.imageData = imageData
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        tags = try container.decode([String].self, forKey: .tags)
        emoji = try container.decode(String.self, forKey: .emoji)
        dishDescription = try container.decode(String.self, forKey: .dishDescription)
        ingredients = try container.decode([String].self, forKey: .ingredients)
        cookNote = try container.decode(String.self, forKey: .cookNote)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        if let base64 = try container.decodeIfPresent(String.self, forKey: .imageBase64) {
            imageData = Data(base64Encoded: base64)
        } else {
            imageData = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encode(tags, forKey: .tags)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(dishDescription, forKey: .dishDescription)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(cookNote, forKey: .cookNote)
        try container.encode(isFavorite, forKey: .isFavorite)
        if let data = imageData {
            try container.encode(data.base64EncodedString(), forKey: .imageBase64)
        }
    }
    
    static func == (lhs: Dish, rhs: Dish) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Observable
final class MealOrder: Codable, Identifiable, Hashable {
    var id: UUID
    var orderDate: Date
    var note: String
    var isFulfilled: Bool
    var memberId: UUID
    var dishId: UUID?
    
    // In-memory resolved references for UI
    var member: FamilyMember?
    var dish: Dish?
    
    enum CodingKeys: String, CodingKey {
        case id
        case orderDate = "order_date"
        case note
        case isFulfilled = "is_fulfilled"
        case memberId = "member_id"
        case dishId = "dish_id"
    }
    
    init(id: UUID = UUID(), member: FamilyMember, dish: Dish, note: String = "", orderDate: Date = Date()) {
        self.id = id
        self.orderDate = orderDate
        self.note = note
        self.isFulfilled = false
        self.memberId = member.id
        self.dishId = dish.id
        self.member = member
        self.dish = dish
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        orderDate = try container.decode(Date.self, forKey: .orderDate)
        note = try container.decode(String.self, forKey: .note)
        isFulfilled = try container.decode(Bool.self, forKey: .isFulfilled)
        memberId = try container.decode(UUID.self, forKey: .memberId)
        dishId = try container.decodeIfPresent(UUID.self, forKey: .dishId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(orderDate, forKey: .orderDate)
        try container.encode(note, forKey: .note)
        try container.encode(isFulfilled, forKey: .isFulfilled)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(dishId, forKey: .dishId)
    }
    
    static func == (lhs: MealOrder, rhs: MealOrder) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
