import XCTest
import SwiftData

final class FamilyRecipesTests: XCTestCase {
    
    // Helper to generate a clean, isolated in-memory model container
    func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: FamilyMember.self, Dish.self, MealOrder.self, FoodDiary.self,
            configurations: config
        )
    }
    
    // Helper to parse ISO8601 date string
    func parseDate(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string) ?? Date()
    }
    
    // MARK: - 1. SwiftData CRUD Tests
    
    func testFamilyMemberCRUD() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let id = UUID()
        let name = "妈妈"
        let emoji = "👩‍🍳"
        let role = "Cook"
        let date = Date()
        
        // 1. Create
        let member = FamilyMember(id: id, name: name, emoji: emoji, role: role, updatedAt: date)
        context.insert(member)
        try context.save()
        
        // 2. Read
        let fetchDescriptor = FetchDescriptor<FamilyMember>()
        var members = try context.fetch(fetchDescriptor)
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members.first?.id, id)
        XCTAssertEqual(members.first?.name, name)
        XCTAssertEqual(members.first?.role, role)
        
        // 3. Update
        members.first?.name = "母亲"
        try context.save()
        
        let updatedMembers = try context.fetch(fetchDescriptor)
        XCTAssertEqual(updatedMembers.first?.name, "母亲")
        
        // 4. Delete
        context.delete(member)
        try context.save()
        
        let deletedMembers = try context.fetch(fetchDescriptor)
        XCTAssertEqual(deletedMembers.count, 0)
    }
    
    func testDishCRUD() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let id = UUID()
        let dish = Dish(
            id: id,
            name: "红烧肉",
            category: "荤菜",
            tags: ["咸甜", "下饭"],
            emoji: "🥩",
            dishDescription: "招牌红烧肉",
            ingredients: ["五花肉", "冰糖"],
            cookNote: "小火慢炖",
            isFavorite: true,
            imageData: Data([1, 2, 3])
        )
        
        // 1. Create
        context.insert(dish)
        try context.save()
        
        // 2. Read
        let fetchDescriptor = FetchDescriptor<Dish>()
        var dishes = try context.fetch(fetchDescriptor)
        XCTAssertEqual(dishes.count, 1)
        XCTAssertEqual(dishes.first?.id, id)
        XCTAssertEqual(dishes.first?.name, "红烧肉")
        XCTAssertEqual(dishes.first?.tags, ["咸甜", "下饭"])
        XCTAssertEqual(dishes.first?.isFavorite, true)
        XCTAssertEqual(dishes.first?.imageData, Data([1, 2, 3]))
        
        // 3. Update
        dishes.first?.isFavorite = false
        try context.save()
        
        let updatedDishes = try context.fetch(fetchDescriptor)
        XCTAssertEqual(updatedDishes.first?.isFavorite, false)
        
        // 4. Delete
        context.delete(dish)
        try context.save()
        
        let deletedDishes = try context.fetch(fetchDescriptor)
        XCTAssertEqual(deletedDishes.count, 0)
    }
    
    func testMealOrderCRUD() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let id = UUID()
        let order = MealOrder(id: id, note: "不要辣", isFulfilled: false)
        
        // 1. Create
        context.insert(order)
        try context.save()
        
        // 2. Read
        let fetchDescriptor = FetchDescriptor<MealOrder>()
        var orders = try context.fetch(fetchDescriptor)
        XCTAssertEqual(orders.count, 1)
        XCTAssertEqual(orders.first?.id, id)
        XCTAssertEqual(orders.first?.note, "不要辣")
        
        // 3. Update
        orders.first?.isFulfilled = true
        try context.save()
        
        let updatedOrders = try context.fetch(fetchDescriptor)
        XCTAssertEqual(updatedOrders.first?.isFulfilled, true)
        
        // 4. Delete
        context.delete(order)
        try context.save()
        
        let deletedOrders = try context.fetch(fetchDescriptor)
        XCTAssertEqual(deletedOrders.count, 0)
    }
    
    func testFoodDiaryCRUD() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let id = UUID()
        let diary = FoodDiary(id: id, rating: 5, comment: "太棒了")
        
        // 1. Create
        context.insert(diary)
        try context.save()
        
        // 2. Read
        let fetchDescriptor = FetchDescriptor<FoodDiary>()
        var diaries = try context.fetch(fetchDescriptor)
        XCTAssertEqual(diaries.count, 1)
        XCTAssertEqual(diaries.first?.id, id)
        XCTAssertEqual(diaries.first?.rating, 5)
        XCTAssertEqual(diaries.first?.comment, "太棒了")
        
        // 3. Update
        diaries.first?.rating = 4
        try context.save()
        
        let updatedDiaries = try context.fetch(fetchDescriptor)
        XCTAssertEqual(updatedDiaries.first?.rating, 4)
        
        // 4. Delete
        context.delete(diary)
        try context.save()
        
        let deletedDiaries = try context.fetch(fetchDescriptor)
        XCTAssertEqual(deletedDiaries.count, 0)
    }
    
    // MARK: - Relationships & Cascaded Deletes
    
    func testFamilyMemberCascadeDelete() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let member = FamilyMember(name: "爸爸", emoji: "👨")
        let dish = Dish(name: "青蒸鱼", category: "荤菜", emoji: "🐟")
        
        let order = MealOrder(member: member, dish: dish, note: "多葱")
        let diary = FoodDiary(rating: 5, comment: "很好吃", member: member, dish: dish)
        
        context.insert(member)
        context.insert(dish)
        context.insert(order)
        context.insert(diary)
        try context.save()
        
        // Verify insertions and relationship setup
        XCTAssertEqual(try context.fetch(FetchDescriptor<FamilyMember>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MealOrder>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodDiary>()).count, 1)
        
        // Delete FamilyMember -> MealOrder and FoodDiary must cascade delete
        context.delete(member)
        try context.save()
        
        XCTAssertEqual(try context.fetch(FetchDescriptor<FamilyMember>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MealOrder>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodDiary>()).count, 0)
        
        // Dish should remain in the database (nullify relationship delete rule)
        let remainingDishes = try context.fetch(FetchDescriptor<Dish>())
        XCTAssertEqual(remainingDishes.count, 1)
    }
    
    func testDishNullifyDelete() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let member = FamilyMember(name: "宝贝", emoji: "👧")
        let dish = Dish(name: "番茄炒蛋", category: "素菜", emoji: "🍳")
        
        let order = MealOrder(member: member, dish: dish, note: "多汁")
        let diary = FoodDiary(rating: 5, comment: "爱吃", member: member, dish: dish)
        
        context.insert(member)
        context.insert(dish)
        context.insert(order)
        context.insert(diary)
        try context.save()
        
        // Delete Dish -> MealOrder and FoodDiary must remain, but their `dish` property should become nil
        context.delete(dish)
        try context.save()
        
        XCTAssertEqual(try context.fetch(FetchDescriptor<Dish>()).count, 0)
        
        let remainingOrders = try context.fetch(FetchDescriptor<MealOrder>())
        XCTAssertEqual(remainingOrders.count, 1)
        XCTAssertNil(remainingOrders.first?.dish)
        
        let remainingDiaries = try context.fetch(FetchDescriptor<FoodDiary>())
        XCTAssertEqual(remainingDiaries.count, 1)
        XCTAssertNil(remainingDiaries.first?.dish)
        
        // FamilyMember should remain unaffected
        XCTAssertEqual(try context.fetch(FetchDescriptor<FamilyMember>()).count, 1)
    }
    
    // MARK: - 2. DTO Parsing & Mapping Tests
    
    func testMemberDTOParsingAndMapping() throws {
        let validJSON = """
        {
            "id": "12345678-1234-1234-1234-1234567890ab",
            "name": "妈妈",
            "emoji": "👩‍🍳",
            "role": "Cook",
            "updated_at": "2026-07-11T09:12:00Z"
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // 1. Parsing Valid JSON
        let dto = try decoder.decode(MemberDTO.self, from: Data(validJSON.utf8))
        XCTAssertEqual(dto.id, UUID(uuidString: "12345678-1234-1234-1234-1234567890ab"))
        XCTAssertEqual(dto.name, "妈妈")
        XCTAssertEqual(dto.updatedAt, parseDate("2026-07-11T09:12:00Z"))
        
        // 2. Parsing Invalid JSON
        let invalidJSON = """
        {
            "id": "invalid-uuid",
            "name": "妈妈",
            "emoji": "👩‍🍳",
            "role": "Cook",
            "updated_at": "invalid-date-format"
        }
        """
        XCTAssertThrowsError(try decoder.decode(MemberDTO.self, from: Data(invalidJSON.utf8)))
        
        // 3. DTO to SwiftData Mapping
        let member = FamilyMember(name: "Initial Name", emoji: "👴")
        member.update(from: dto)
        XCTAssertEqual(member.name, "妈妈")
        XCTAssertEqual(member.emoji, "👩‍🍳")
        XCTAssertEqual(member.role, "Cook")
        XCTAssertEqual(member.updatedAt, parseDate("2026-07-11T09:12:00Z"))
        
        // 4. SwiftData to DTO Mapping
        let modelDTO = member.dto
        XCTAssertEqual(modelDTO.id, member.id)
        XCTAssertEqual(modelDTO.name, "妈妈")
        XCTAssertEqual(modelDTO.role, "Cook")
        XCTAssertEqual(modelDTO.updatedAt, member.updatedAt)
    }
    
    func testDishDTOParsingAndMapping() throws {
        let validJSON = """
        {
            "id": "23456789-2345-2345-2345-2345678901bc",
            "name": "清蒸鲈鱼",
            "category": "荤菜",
            "tags": ["鲜美", "清淡"],
            "emoji": "🐟",
            "dish_description": "鱼肉鲜美",
            "ingredients": ["鲈鱼", "姜"],
            "cook_note": "大火蒸7分钟",
            "is_favorite": true,
            "image_base64": "AQID",
            "updated_at": "2026-07-11T09:12:00Z"
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // 1. Parsing Valid JSON
        let dto = try decoder.decode(DishDTO.self, from: Data(validJSON.utf8))
        XCTAssertEqual(dto.name, "清蒸鲈鱼")
        XCTAssertEqual(dto.imageBase64, "AQID")
        
        // 2. Parsing Invalid JSON (missing field)
        let invalidJSON = """
        {
            "id": "23456789-2345-2345-2345-2345678901bc",
            "name": "清蒸鲈鱼"
        }
        """
        XCTAssertThrowsError(try decoder.decode(DishDTO.self, from: Data(invalidJSON.utf8)))
        
        // 3. DTO to SwiftData Mapping
        let dish = Dish(name: "Temp", category: "Temp", emoji: "Temp")
        dish.update(from: dto)
        XCTAssertEqual(dish.name, "清蒸鲈鱼")
        XCTAssertEqual(dish.tags, ["鲜美", "清淡"])
        XCTAssertEqual(dish.cookNote, "大火蒸7分钟")
        XCTAssertEqual(dish.isFavorite, true)
        XCTAssertEqual(dish.imageData, Data([1, 2, 3])) // "AQID" is Base64 for [1, 2, 3]
        
        // 4. SwiftData to DTO Mapping
        let modelDTO = dish.dto
        XCTAssertEqual(modelDTO.name, "清蒸鲈鱼")
        XCTAssertEqual(modelDTO.imageBase64, "AQID")
    }
    
    func testOrderDTOParsingAndMapping() throws {
        let validJSON = """
        {
            "id": "34567890-3456-3456-3456-3456789012cd",
            "order_date": "2026-07-11T09:12:00Z",
            "note": "少糖",
            "is_fulfilled": true,
            "member_id": "12345678-1234-1234-1234-1234567890ab",
            "dish_id": "23456789-2345-2345-2345-2345678901bc",
            "updated_at": "2026-07-11T09:12:00Z"
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // 1. Parsing Valid JSON
        let dto = try decoder.decode(OrderDTO.self, from: Data(validJSON.utf8))
        XCTAssertEqual(dto.note, "少糖")
        XCTAssertTrue(dto.isFulfilled)
        
        // 2. Parsing Invalid JSON (wrong types)
        let invalidJSON = """
        {
            "id": "34567890-3456-3456-3456-3456789012cd",
            "is_fulfilled": "not-a-bool"
        }
        """
        XCTAssertThrowsError(try decoder.decode(OrderDTO.self, from: Data(invalidJSON.utf8)))
        
        // 3. DTO to SwiftData Mapping
        let order = MealOrder(note: "Original Note", isFulfilled: false)
        order.update(from: dto)
        XCTAssertEqual(order.note, "少糖")
        XCTAssertTrue(order.isFulfilled)
        XCTAssertEqual(order.orderDate, parseDate("2026-07-11T09:12:00Z"))
        
        // 4. SwiftData to DTO Mapping
        let member = FamilyMember(id: UUID(uuidString: "12345678-1234-1234-1234-1234567890ab")!, name: "Test Member", emoji: "👩‍🍳")
        let dish = Dish(id: UUID(uuidString: "23456789-2345-2345-2345-2345678901bc")!, name: "Test Dish", category: "荤菜", emoji: "🍳")
        order.member = member
        order.dish = dish
        
        let modelDTO = order.dto
        XCTAssertEqual(modelDTO.note, "少糖")
        XCTAssertEqual(modelDTO.memberId, member.id)
        XCTAssertEqual(modelDTO.dishId, dish.id)
    }
    
    func testDiaryDTOParsingAndMapping() throws {
        let validJSON = """
        {
            "id": "45678901-4567-4567-4567-4567890123de",
            "diary_date": "2026-07-11",
            "rating": 5,
            "comment": "非常好吃",
            "member_id": "12345678-1234-1234-1234-1234567890ab",
            "dish_id": "23456789-2345-2345-2345-2345678901bc",
            "image_base64": "AQID",
            "updated_at": "2026-07-11T09:12:00Z"
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // 1. Parsing Valid JSON
        let dto = try decoder.decode(DiaryDTO.self, from: Data(validJSON.utf8))
        XCTAssertEqual(dto.diaryDate, "2026-07-11")
        XCTAssertEqual(dto.rating, 5)
        XCTAssertEqual(dto.imageBase64, "AQID")
        
        // 2. Parsing Invalid JSON (wrong types)
        let invalidJSON = """
        {
            "id": "45678901-4567-4567-4567-4567890123de",
            "rating": "five"
        }
        """
        XCTAssertThrowsError(try decoder.decode(DiaryDTO.self, from: Data(invalidJSON.utf8)))
        
        // 3. DTO to SwiftData Mapping
        let diary = FoodDiary(rating: 1, comment: "Original")
        diary.update(from: dto)
        XCTAssertEqual(diary.rating, 5)
        XCTAssertEqual(diary.comment, "非常好吃")
        XCTAssertEqual(diary.imageData, Data([1, 2, 3]))
        
        let calendar = Calendar.current
        let year = calendar.component(.year, from: diary.diaryDate)
        let month = calendar.component(.month, from: diary.diaryDate)
        let day = calendar.component(.day, from: diary.diaryDate)
        XCTAssertEqual(year, 2026)
        XCTAssertEqual(month, 7)
        XCTAssertEqual(day, 11)
        
        // 4. SwiftData to DTO Mapping
        let member = FamilyMember(id: UUID(uuidString: "12345678-1234-1234-1234-1234567890ab")!, name: "Test Member", emoji: "👩‍🍳")
        let dish = Dish(id: UUID(uuidString: "23456789-2345-2345-2345-2345678901bc")!, name: "Test Dish", category: "荤菜", emoji: "🍳")
        diary.member = member
        diary.dish = dish
        
        let modelDTO = diary.dto
        XCTAssertEqual(modelDTO.rating, 5)
        XCTAssertEqual(modelDTO.diaryDate, "2026-07-11")
        XCTAssertEqual(modelDTO.memberId, member.id)
        XCTAssertEqual(modelDTO.dishId, dish.id)
        XCTAssertEqual(modelDTO.imageBase64, "AQID")
    }
    
    // MARK: - 3. SyncEngine Merger Conflict Resolution (Last-Write-Wins)
    
    @MainActor
    func testSyncEngineLastWriteWins() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        // Mock AppState setup
        let appState = AppState()
        appState.setSupabaseURL("https://mock.supabase.co")
        appState.setSupabaseKey("mock_key")
        
        let memberId = UUID()
        let dishId = UUID()
        let orderId = UUID()
        let diaryId = UUID()
        
        let baseTime = parseDate("2026-07-11T12:00:00Z")
        let newerTime = parseDate("2026-07-11T12:05:00Z")
        let olderTime = parseDate("2026-07-11T11:55:00Z")
        
        // Initial setup of local records in SwiftData
        let localMember = FamilyMember(id: memberId, name: "Local Member", emoji: "👨", role: "Member", updatedAt: baseTime)
        let localDish = Dish(id: dishId, name: "Local Dish", category: "素菜", emoji: "🍳", updatedAt: baseTime)
        let localOrder = MealOrder(id: orderId, note: "Local Note", orderDate: baseTime, isFulfilled: false, updatedAt: baseTime)
        let localDiary = FoodDiary(id: diaryId, diaryDate: baseTime, rating: 3, comment: "Local Comment", updatedAt: baseTime)
        
        context.insert(localMember)
        context.insert(localDish)
        context.insert(localOrder)
        context.insert(localDiary)
        
        localOrder.member = localMember
        localOrder.dish = localDish
        localDiary.member = localMember
        localDiary.dish = localDish
        
        try context.save()
        
        // --- CASE 1: Newer remote record should OVERWRITE the local record ---
        
        let newerRemoteMember = MemberDTO(id: memberId, name: "Newer Remote Member", emoji: "👩", role: "Member", updatedAt: newerTime)
        let newerRemoteDish = DishDTO(id: dishId, name: "Newer Remote Dish", category: "荤菜", tags: ["New"], emoji: "🥩", dishDescription: "New", ingredients: [], cookNote: "New", isFavorite: true, imageBase64: nil, updatedAt: newerTime)
        let newerRemoteOrder = OrderDTO(id: orderId, orderDate: newerTime, note: "Newer Remote Note", isFulfilled: true, memberId: memberId, dishId: dishId, updatedAt: newerTime)
        let newerRemoteDiary = DiaryDTO(id: diaryId, diaryDate: "2026-07-11", rating: 5, comment: "Newer Remote Comment", memberId: memberId, dishId: dishId, imageBase64: nil, updatedAt: newerTime)
        
        SupabaseManager.shared.mockMembers = [newerRemoteMember]
        SupabaseManager.shared.mockDishes = [newerRemoteDish]
        SupabaseManager.shared.mockOrders = [newerRemoteOrder]
        SupabaseManager.shared.mockDiaries = [newerRemoteDiary]
        
        // Trigger Sync Down
        await SyncEngine.shared.syncDown(context: context, appState: appState)
        
        // Verify Local Overwritten
        let fetchedMembers1 = try context.fetch(FetchDescriptor<FamilyMember>())
        XCTAssertEqual(fetchedMembers1.first(where: { $0.id == memberId })?.name, "Newer Remote Member")
        
        let fetchedDishes1 = try context.fetch(FetchDescriptor<Dish>())
        XCTAssertEqual(fetchedDishes1.first(where: { $0.id == dishId })?.name, "Newer Remote Dish")
        
        let fetchedOrders1 = try context.fetch(FetchDescriptor<MealOrder>())
        XCTAssertEqual(fetchedOrders1.first(where: { $0.id == orderId })?.note, "Newer Remote Note")
        XCTAssertEqual(fetchedOrders1.first(where: { $0.id == orderId })?.isFulfilled, true)
        
        let fetchedDiaries1 = try context.fetch(FetchDescriptor<FoodDiary>())
        XCTAssertEqual(fetchedDiaries1.first(where: { $0.id == diaryId })?.comment, "Newer Remote Comment")
        XCTAssertEqual(fetchedDiaries1.first(where: { $0.id == diaryId })?.rating, 5)
        
        // --- CASE 2: Older remote record should NOT OVERWRITE local record ---
        
        // Set local record updatedAt to newerTime
        let curMember = fetchedMembers1.first(where: { $0.id == memberId })!
        let curDish = fetchedDishes1.first(where: { $0.id == dishId })!
        let curOrder = fetchedOrders1.first(where: { $0.id == orderId })!
        let curDiary = fetchedDiaries1.first(where: { $0.id == diaryId })!
        
        curMember.name = "Keep Me"
        curMember.updatedAt = newerTime
        curDish.name = "Keep Me"
        curDish.updatedAt = newerTime
        curOrder.note = "Keep Me"
        curOrder.updatedAt = newerTime
        curDiary.comment = "Keep Me"
        curDiary.updatedAt = newerTime
        try context.save()
        
        // Set older remote records (older than newerTime)
        let olderRemoteMember = MemberDTO(id: memberId, name: "Older Remote Member", emoji: "👩", role: "Member", updatedAt: olderTime)
        let olderRemoteDish = DishDTO(id: dishId, name: "Older Remote Dish", category: "荤菜", tags: ["Old"], emoji: "🥩", dishDescription: "Old", ingredients: [], cookNote: "Old", isFavorite: false, imageBase64: nil, updatedAt: olderTime)
        let olderRemoteOrder = OrderDTO(id: orderId, orderDate: olderTime, note: "Older Remote Note", isFulfilled: false, memberId: memberId, dishId: dishId, updatedAt: olderTime)
        let olderRemoteDiary = DiaryDTO(id: diaryId, diaryDate: "2026-07-11", rating: 1, comment: "Older Remote Comment", memberId: memberId, dishId: dishId, imageBase64: nil, updatedAt: olderTime)
        
        SupabaseManager.shared.mockMembers = [olderRemoteMember]
        SupabaseManager.shared.mockDishes = [olderRemoteDish]
        SupabaseManager.shared.mockOrders = [olderRemoteOrder]
        SupabaseManager.shared.mockDiaries = [olderRemoteDiary]
        
        // Trigger Sync Down
        await SyncEngine.shared.syncDown(context: context, appState: appState)
        
        // Verify Local Unchanged
        let fetchedMembers2 = try context.fetch(FetchDescriptor<FamilyMember>())
        XCTAssertEqual(fetchedMembers2.first(where: { $0.id == memberId })?.name, "Keep Me")
        
        let fetchedDishes2 = try context.fetch(FetchDescriptor<Dish>())
        XCTAssertEqual(fetchedDishes2.first(where: { $0.id == dishId })?.name, "Keep Me")
        
        let fetchedOrders2 = try context.fetch(FetchDescriptor<MealOrder>())
        XCTAssertEqual(fetchedOrders2.first(where: { $0.id == orderId })?.note, "Keep Me")
        
        let fetchedDiaries2 = try context.fetch(FetchDescriptor<FoodDiary>())
        XCTAssertEqual(fetchedDiaries2.first(where: { $0.id == diaryId })?.comment, "Keep Me")
        
        // Clean up mock references
        SupabaseManager.shared.mockMembers = nil
        SupabaseManager.shared.mockDishes = nil
        SupabaseManager.shared.mockOrders = nil
        SupabaseManager.shared.mockDiaries = nil
    }
}
