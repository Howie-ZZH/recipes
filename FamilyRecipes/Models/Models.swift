import Foundation
import SwiftData

@Model
final class FamilyMember {
    @Attribute(.unique) var id: UUID
    var name: String
    var emoji: String
    var role: String // "Cook" (掌勺人) 或 "Member" (普通家庭成员)
    var updatedAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \MealOrder.member)
    var orders: [MealOrder]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \FoodDiary.member)
    var diaries: [FoodDiary]? = []
    
    init(id: UUID = UUID(), name: String, emoji: String, role: String = "Member", updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.role = role
        self.updatedAt = updatedAt
    }
}

@Model
final class Dish {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String // "荤菜", "素菜", "汤羹", "主食", "甜品/其他"
    var tags: [String] // ["辣", "清淡", "高蛋白", "快手菜"]
    var emoji: String // 用 Emoji 作为菜名图标
    var dishDescription: String
    var ingredients: [String] // 食材原料列表，用于自动生成买菜清单
    var cookNote: String
    var isFavorite: Bool
    var imageData: Data?
    var updatedAt: Date
    
    @Relationship(deleteRule: .nullify, inverse: \MealOrder.dish)
    var orders: [MealOrder]? = []
    
    @Relationship(deleteRule: .nullify, inverse: \FoodDiary.dish)
    var diaries: [FoodDiary]? = []
    
    init(id: UUID = UUID(), name: String, category: String, tags: [String] = [], emoji: String, dishDescription: String = "", ingredients: [String] = [], cookNote: String = "", isFavorite: Bool = false, imageData: Data? = nil, updatedAt: Date = Date()) {
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
        self.updatedAt = updatedAt
    }
}

@Model
final class MealOrder {
    @Attribute(.unique) var id: UUID
    var orderDate: Date
    var note: String
    var isFulfilled: Bool
    var updatedAt: Date
    
    var member: FamilyMember?
    var dish: Dish?
    
    init(id: UUID = UUID(), member: FamilyMember? = nil, dish: Dish? = nil, note: String = "", orderDate: Date = Date(), isFulfilled: Bool = false, updatedAt: Date = Date()) {
        self.id = id
        self.member = member
        self.dish = dish
        self.orderDate = orderDate
        self.note = note
        self.isFulfilled = isFulfilled
        self.updatedAt = updatedAt
    }
}

@Model
final class FoodDiary {
    @Attribute(.unique) var id: UUID
    var diaryDate: Date
    var rating: Int
    var comment: String
    var imageData: Data?
    var updatedAt: Date
    
    var member: FamilyMember?
    var dish: Dish?
    
    init(id: UUID = UUID(), diaryDate: Date = Date(), rating: Int, comment: String = "", member: FamilyMember? = nil, dish: Dish? = nil, imageData: Data? = nil, updatedAt: Date = Date()) {
        self.id = id
        self.diaryDate = diaryDate
        self.rating = rating
        self.comment = comment
        self.member = member
        self.dish = dish
        self.imageData = imageData
        self.updatedAt = updatedAt
    }
}
