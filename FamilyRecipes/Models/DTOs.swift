import Foundation

// Data Transfer Objects for Supabase Network Sync

struct MemberDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var emoji: String
    var role: String
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
        case role
        case updatedAt = "updated_at"
    }
}

extension FamilyMember {
    var dto: MemberDTO {
        MemberDTO(id: id, name: name, emoji: emoji, role: role, updatedAt: updatedAt)
    }
    
    func update(from dto: MemberDTO) {
        self.name = dto.name
        self.emoji = dto.emoji
        self.role = dto.role
        self.updatedAt = dto.updatedAt
    }
}

struct DishDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var category: String
    var tags: [String]
    var emoji: String
    var dishDescription: String
    var ingredients: [String]
    var cookNote: String
    var isFavorite: Bool
    var imageBase64: String?
    var updatedAt: Date
    
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
        case updatedAt = "updated_at"
    }
}

extension Dish {
    var dto: DishDTO {
        DishDTO(
            id: id,
            name: name,
            category: category,
            tags: tags,
            emoji: emoji,
            dishDescription: dishDescription,
            ingredients: ingredients,
            cookNote: cookNote,
            isFavorite: isFavorite,
            imageBase64: imageData?.base64EncodedString(),
            updatedAt: updatedAt
        )
    }
    
    func update(from dto: DishDTO) {
        self.name = dto.name
        self.category = dto.category
        self.tags = dto.tags
        self.emoji = dto.emoji
        self.dishDescription = dto.dishDescription
        self.ingredients = dto.ingredients
        self.cookNote = dto.cookNote
        self.isFavorite = dto.isFavorite
        self.updatedAt = dto.updatedAt
        if let base64 = dto.imageBase64 {
            self.imageData = Data(base64Encoded: base64)
        } else {
            self.imageData = nil
        }
    }
}

struct OrderDTO: Codable, Identifiable {
    var id: UUID
    var orderDate: Date
    var note: String
    var isFulfilled: Bool
    var memberId: UUID
    var dishId: UUID?
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case orderDate = "order_date"
        case note
        case isFulfilled = "is_fulfilled"
        case memberId = "member_id"
        case dishId = "dish_id"
        case updatedAt = "updated_at"
    }
}

extension MealOrder {
    var dto: OrderDTO {
        OrderDTO(
            id: id,
            orderDate: orderDate,
            note: note,
            isFulfilled: isFulfilled,
            memberId: member?.id ?? UUID(), // Should ideally never be empty if saved correctly
            dishId: dish?.id,
            updatedAt: updatedAt
        )
    }
    
    func update(from dto: OrderDTO) {
        self.orderDate = dto.orderDate
        self.note = dto.note
        self.isFulfilled = dto.isFulfilled
        self.updatedAt = dto.updatedAt
    }
}

struct DiaryDTO: Codable, Identifiable {
    var id: UUID
    var diaryDate: String
    var rating: Int
    var comment: String
    var memberId: UUID
    var dishId: UUID
    var imageBase64: String?
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case diaryDate = "diary_date"
        case rating
        case comment
        case memberId = "member_id"
        case dishId = "dish_id"
        case imageBase64 = "image_base64"
        case updatedAt = "updated_at"
    }
}

extension FoodDiary {
    var dto: DiaryDTO {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: diaryDate)
        
        return DiaryDTO(
            id: id,
            diaryDate: dateString,
            rating: rating,
            comment: comment,
            memberId: member?.id ?? UUID(),
            dishId: dish?.id ?? UUID(),
            imageBase64: imageData?.base64EncodedString(),
            updatedAt: updatedAt
        )
    }
    
    func update(from dto: DiaryDTO) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dto.diaryDate) {
            self.diaryDate = date
        }
        self.rating = dto.rating
        self.comment = dto.comment
        self.updatedAt = dto.updatedAt
        if let base64 = dto.imageBase64 {
            self.imageData = Data(base64Encoded: base64)
        } else {
            self.imageData = nil
        }
    }
}
