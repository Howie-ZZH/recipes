import Foundation

// Data Transfer Objects for PostgREST / Supabase Network Sync

// MARK: - 1. Family Member DTO

struct MemberDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var emoji: String
    var role: String
    var updatedAt: Date
    var deletedAt: Date?
    
    var isDeleted: Bool {
        deletedAt != nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
        case role
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
    
    init(id: UUID, name: String, emoji: String, role: String, updatedAt: Date = Date(), deletedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.role = role
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.emoji = try container.decode(String.self, forKey: .emoji)
        self.role = try container.decode(String.self, forKey: .role)
        self.updatedAt = (try? container.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? Date()
        self.deletedAt = try? container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(role, forKey: .role)
        try container.encode(updatedAt, forKey: .updatedAt)
        if let deletedAt = deletedAt {
            try container.encode(deletedAt, forKey: .deletedAt)
        }
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

// MARK: - 2. Dish DTO

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
    var deletedAt: Date?
    
    var isDeleted: Bool {
        deletedAt != nil
    }
    
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
        case deletedAt = "deleted_at"
    }
    
    init(
        id: UUID,
        name: String,
        category: String,
        tags: [String],
        emoji: String,
        dishDescription: String,
        ingredients: [String],
        cookNote: String,
        isFavorite: Bool,
        imageBase64: String?,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.tags = tags
        self.emoji = emoji
        self.dishDescription = dishDescription
        self.ingredients = ingredients
        self.cookNote = cookNote
        self.isFavorite = isFavorite
        self.imageBase64 = imageBase64
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.category = try container.decode(String.self, forKey: .category)
        self.tags = (try? container.decode([String].self, forKey: .tags)) ?? []
        self.emoji = try container.decode(String.self, forKey: .emoji)
        self.dishDescription = (try? container.decode(String.self, forKey: .dishDescription)) ?? ""
        self.ingredients = (try? container.decode([String].self, forKey: .ingredients)) ?? []
        self.cookNote = (try? container.decode(String.self, forKey: .cookNote)) ?? ""
        self.isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        self.imageBase64 = try container.decodeIfPresent(String.self, forKey: .imageBase64)
        self.updatedAt = (try? container.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? Date()
        self.deletedAt = try? container.decodeIfPresent(Date.self, forKey: .deletedAt)
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
        try container.encodeIfPresent(imageBase64, forKey: .imageBase64)
        try container.encode(updatedAt, forKey: .updatedAt)
        if let deletedAt = deletedAt {
            try container.encode(deletedAt, forKey: .deletedAt)
        }
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
            imageBase64: ImageUtils.compressImageToBase64(imageData),
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
        if let base64 = dto.imageBase64, !base64.isEmpty {
            self.imageData = Data(base64Encoded: base64)
        } else {
            self.imageData = nil
        }
    }
}

// MARK: - 3. Meal Order DTO

struct OrderDTO: Codable, Identifiable {
    var id: UUID
    var orderDate: Date
    var note: String
    var isFulfilled: Bool
    var memberId: UUID
    var dishId: UUID?
    var updatedAt: Date
    var deletedAt: Date?
    
    var isDeleted: Bool {
        deletedAt != nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case orderDate = "order_date"
        case note
        case isFulfilled = "is_fulfilled"
        case memberId = "member_id"
        case dishId = "dish_id"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
    
    init(
        id: UUID,
        orderDate: Date,
        note: String,
        isFulfilled: Bool,
        memberId: UUID,
        dishId: UUID?,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.orderDate = orderDate
        self.note = note
        self.isFulfilled = isFulfilled
        self.memberId = memberId
        self.dishId = dishId
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.orderDate = try container.decode(Date.self, forKey: .orderDate)
        self.note = try container.decode(String.self, forKey: .note)
        self.isFulfilled = try container.decode(Bool.self, forKey: .isFulfilled)
        self.memberId = try container.decode(UUID.self, forKey: .memberId)
        self.dishId = try container.decodeIfPresent(UUID.self, forKey: .dishId)
        self.updatedAt = (try? container.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? Date()
        self.deletedAt = try? container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(orderDate, forKey: .orderDate)
        try container.encode(note, forKey: .note)
        try container.encode(isFulfilled, forKey: .isFulfilled)
        try container.encode(memberId, forKey: .memberId)
        try container.encodeIfPresent(dishId, forKey: .dishId)
        try container.encode(updatedAt, forKey: .updatedAt)
        if let deletedAt = deletedAt {
            try container.encode(deletedAt, forKey: .deletedAt)
        }
    }
}

extension MealOrder {
    var dto: OrderDTO {
        OrderDTO(
            id: id,
            orderDate: orderDate,
            note: note,
            isFulfilled: isFulfilled,
            memberId: member?.id ?? UUID(),
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

// MARK: - 4. Food Diary DTO

struct DiaryDTO: Codable, Identifiable {
    var id: UUID
    var diaryDate: String
    var rating: Int
    var comment: String
    var memberId: UUID
    var dishId: UUID
    var imageBase64: String?
    var updatedAt: Date
    var deletedAt: Date?
    
    var isDeleted: Bool {
        deletedAt != nil
    }
    
    /// Robust helper to parse diaryDate string into a Date, supporting yyyy-MM-dd, ISO8601, and timestamp formats.
    var parsedDiaryDate: Date? {
        // 1. Try standard date format yyyy-MM-dd
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        simpleFormatter.timeZone = TimeZone.current
        if let date = simpleFormatter.date(from: diaryDate) {
            return date
        }
        
        // 2. Try ISO8601 with fractional seconds
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: diaryDate) {
            return date
        }
        
        // 3. Try standard ISO8601
        let strictIso = ISO8601DateFormatter()
        if let date = strictIso.date(from: diaryDate) {
            return date
        }
        
        // 4. Try yyyy-MM-dd HH:mm:ss
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateTimeFormatter.timeZone = TimeZone.current
        if let date = dateTimeFormatter.date(from: diaryDate) {
            return date
        }
        
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case diaryDate = "diary_date"
        case rating
        case comment
        case memberId = "member_id"
        case dishId = "dish_id"
        case imageBase64 = "image_base64"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
    
    init(
        id: UUID,
        diaryDate: String,
        rating: Int,
        comment: String,
        memberId: UUID,
        dishId: UUID,
        imageBase64: String?,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.diaryDate = diaryDate
        self.rating = rating
        self.comment = comment
        self.memberId = memberId
        self.dishId = dishId
        self.imageBase64 = imageBase64
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.diaryDate = try container.decode(String.self, forKey: .diaryDate)
        self.rating = try container.decode(Int.self, forKey: .rating)
        self.comment = try container.decode(String.self, forKey: .comment)
        self.memberId = try container.decode(UUID.self, forKey: .memberId)
        self.dishId = try container.decode(UUID.self, forKey: .dishId)
        self.imageBase64 = try container.decodeIfPresent(String.self, forKey: .imageBase64)
        self.updatedAt = (try? container.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? Date()
        self.deletedAt = try? container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(diaryDate, forKey: .diaryDate)
        try container.encode(rating, forKey: .rating)
        try container.encode(comment, forKey: .comment)
        try container.encode(memberId, forKey: .memberId)
        try container.encode(dishId, forKey: .dishId)
        try container.encodeIfPresent(imageBase64, forKey: .imageBase64)
        try container.encode(updatedAt, forKey: .updatedAt)
        if let deletedAt = deletedAt {
            try container.encode(deletedAt, forKey: .deletedAt)
        }
    }
}

extension FoodDiary {
    var dto: DiaryDTO {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let dateString = formatter.string(from: diaryDate)
        
        return DiaryDTO(
            id: id,
            diaryDate: dateString,
            rating: rating,
            comment: comment,
            memberId: member?.id ?? UUID(),
            dishId: dish?.id ?? UUID(),
            imageBase64: ImageUtils.compressImageToBase64(imageData),
            updatedAt: updatedAt
        )
    }
    
    func update(from dto: DiaryDTO) {
        if let date = dto.parsedDiaryDate {
            self.diaryDate = date
        }
        self.rating = dto.rating
        self.comment = dto.comment
        self.updatedAt = dto.updatedAt
        if let base64 = dto.imageBase64, !base64.isEmpty {
            self.imageData = Data(base64Encoded: base64)
        } else {
            self.imageData = nil
        }
    }
}
