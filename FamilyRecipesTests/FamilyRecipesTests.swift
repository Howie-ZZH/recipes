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
        appState.resetSyncCursor()
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

    @MainActor
    func testSyncEnginePrunesStaleLocalRecords() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let appState = AppState()
        appState.resetSyncCursor()
        appState.setSupabaseURL("https://mock.supabase.co")
        
        let keptMemberId = UUID()
        let staleMemberId = UUID()
        
        let keptMember = FamilyMember(id: keptMemberId, name: "Keep Me", emoji: "👨", role: "Cook")
        let staleMember = FamilyMember(id: staleMemberId, name: "Delete Me", emoji: "👦", role: "Member")
        
        context.insert(keptMember)
        context.insert(staleMember)
        try context.save()
        
        appState.activeMemberId = staleMemberId
        
        // Remote only has keptMember
        let remoteMember = MemberDTO(id: keptMemberId, name: "Keep Me", emoji: "👨", role: "Cook", updatedAt: Date())
        SupabaseManager.shared.mockMembers = [remoteMember]
        SupabaseManager.shared.mockDishes = []
        SupabaseManager.shared.mockOrders = []
        SupabaseManager.shared.mockDiaries = []
        
        await SyncEngine.shared.syncDown(context: context, appState: appState)
        
        let members = try context.fetch(FetchDescriptor<FamilyMember>())
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members.first?.id, keptMemberId)
        XCTAssertNil(appState.activeMemberId) // Stale active member ID should be cleared
        
        SupabaseManager.shared.mockMembers = nil
        SupabaseManager.shared.mockDishes = nil
        SupabaseManager.shared.mockOrders = nil
        SupabaseManager.shared.mockDiaries = nil
    }

    @MainActor
    func testSyncEnginePrunesStaleLocalDishes() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let appState = AppState()
        appState.resetSyncCursor()
        appState.setSupabaseURL("https://mock.supabase.co")
        
        let keptDishId = UUID()
        let deletedOnOtherDeviceDishId = UUID()
        
        let keptDish = Dish(id: keptDishId, name: "番茄炒蛋", category: "素菜", emoji: "🍳")
        let deletedDish = Dish(id: deletedOnOtherDeviceDishId, name: "红烧肉", category: "荤菜", emoji: "🥩")
        
        context.insert(keptDish)
        context.insert(deletedDish)
        try context.save()
        
        // Remote (cloud database) only has keptDish because deletedDish was deleted on another device (e.g. iPhone)
        let remoteDish = DishDTO(
            id: keptDishId,
            name: "番茄炒蛋",
            category: "素菜",
            tags: ["家常菜"],
            emoji: "🍳",
            dishDescription: "酸甜可口",
            ingredients: ["番茄", "鸡蛋"],
            cookNote: "先炒蛋",
            isFavorite: true,
            imageBase64: nil,
            updatedAt: Date()
        )
        
        SupabaseManager.shared.mockMembers = [
            MemberDTO(id: UUID(), name: "妈妈", emoji: "👩‍🍳", role: "Cook", updatedAt: Date())
        ]
        SupabaseManager.shared.mockDishes = [remoteDish]
        SupabaseManager.shared.mockOrders = []
        SupabaseManager.shared.mockDiaries = []
        
        // Simulator syncs down from cloud
        await SyncEngine.shared.syncDown(context: context, appState: appState)
        
        // deletedDish must be deleted locally on simulator, only keptDish remains
        let dishes = try context.fetch(FetchDescriptor<Dish>())
        XCTAssertEqual(dishes.count, 1)
        XCTAssertEqual(dishes.first?.id, keptDishId)
        XCTAssertEqual(dishes.first?.name, "番茄炒蛋")
        
        SupabaseManager.shared.mockMembers = nil
        SupabaseManager.shared.mockDishes = nil
        SupabaseManager.shared.mockOrders = nil
        SupabaseManager.shared.mockDiaries = nil
    }

    // MARK: - 4. PostgREST Wire-Format Date Decoding

    func testPostgRESTDateDecodingWithFractionalSeconds() throws {
        // PostgREST serializes PostgreSQL `timestamptz` with microsecond
        // precision + offset, e.g. "2026-07-11T03:20:48.71102+00:00". Swift's
        // strict `.iso8601` strategy rejects fractional seconds;
        // SupabaseManager.makeDecoder() must accept this real wire format and
        // also columns written without fractional seconds.
        let fractionalJSON = """
        {
            "id": "f3382ac7-28da-4c79-847d-c93701f4b4d4",
            "name": "瑶妹",
            "emoji": "👧",
            "role": "Member",
            "updated_at": "2026-07-11T03:20:48.71102+00:00"
        }
        """
        let dto = try SupabaseManager.makeDecoder().decode(MemberDTO.self, from: Data(fractionalJSON.utf8))
        XCTAssertEqual(dto.name, "瑶妹")
        // Fractional part (0.71102s) must be retained, not dropped.
        let expectedBase = parseDate("2026-07-11T03:20:48Z")
        XCTAssertEqual(dto.updatedAt.timeIntervalSince(expectedBase), 0.71102, accuracy: 0.001)

        // Columns written without fractional seconds must still decode.
        let plainJSON = """
        {
            "id": "c0371b72-3ae1-4766-ad2e-8da782d739ed",
            "order_date": "2026-07-09T15:07:03+00:00",
            "note": "",
            "is_fulfilled": false,
            "member_id": "f3382ac7-28da-4c79-847d-c93701f4b4d4",
            "updated_at": "2026-07-11T03:20:48+00:00"
        }
        """
        let order = try SupabaseManager.makeDecoder().decode(OrderDTO.self, from: Data(plainJSON.utf8))
        XCTAssertEqual(order.orderDate, parseDate("2026-07-09T15:07:03Z"))
        XCTAssertEqual(order.updatedAt, parseDate("2026-07-11T03:20:48Z"))
    }

    // MARK: - 5. Phase 1 Foreground Polling & Deduplication Tests

    @MainActor
    func testSyncEngineDeduplicatesConcurrentSyncDown() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let appState = AppState()
        appState.setSupabaseURL("https://mock.supabase.co")
        
        let memberId = UUID()
        let remoteMember = MemberDTO(id: memberId, name: "并发测试成员", emoji: "👩‍🍳", role: "Cook", updatedAt: Date())
        SupabaseManager.shared.mockMembers = [remoteMember]
        SupabaseManager.shared.mockDishes = []
        SupabaseManager.shared.mockOrders = []
        SupabaseManager.shared.mockDiaries = []
        
        // Concurrently trigger 3 syncDown calls
        async let sync1: Void = SyncEngine.shared.syncDown(context: context, appState: appState)
        async let sync2: Void = SyncEngine.shared.syncDown(context: context, appState: appState)
        async let sync3: Void = SyncEngine.shared.syncDown(context: context, appState: appState)
        
        _ = await (sync1, sync2, sync3)
        
        let members = try context.fetch(FetchDescriptor<FamilyMember>())
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members.first?.id, memberId)
        
        SupabaseManager.shared.mockMembers = nil
    }

    @MainActor
    func testSyncEngineForegroundPollingControl() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let appState = AppState()
        appState.setSupabaseURL("https://mock.supabase.co")
        
        // Start Polling
        SyncEngine.shared.startForegroundPolling(context: context, appState: appState, interval: 0.1)
        XCTAssertTrue(SyncEngine.shared.isPolling)
        
        // Stop Polling
        SyncEngine.shared.stopForegroundPolling()
        XCTAssertFalse(SyncEngine.shared.isPolling)
    }

    // MARK: - 6. Phase 2 Delta Sync, Soft Delete & Cursor Tests

    func testDTOSoftDeleteDecodingAndEncoding() throws {
        let decoder = SupabaseManager.makeDecoder()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // 1. DishDTO with deleted_at
        let dishJSON = """
        {
            "id": "55555555-5555-5555-5555-555555555555",
            "name": "已删菜品",
            "category": "荤菜",
            "tags": [],
            "emoji": "🍲",
            "dish_description": "",
            "ingredients": [],
            "cook_note": "",
            "is_favorite": false,
            "updated_at": "2026-07-11T12:00:00Z",
            "deleted_at": "2026-07-11T12:05:00Z"
        }
        """
        let dishDTO = try decoder.decode(DishDTO.self, from: Data(dishJSON.utf8))
        XCTAssertTrue(dishDTO.isDeleted)
        XCTAssertNotNil(dishDTO.deletedAt)
        XCTAssertEqual(dishDTO.deletedAt, parseDate("2026-07-11T12:05:00Z"))

        // Roundtrip encode
        let encodedDishData = try encoder.encode(dishDTO)
        let roundtripDish = try decoder.decode(DishDTO.self, from: encodedDishData)
        XCTAssertTrue(roundtripDish.isDeleted)
        XCTAssertEqual(roundtripDish.name, "已删菜品")

        // 2. MemberDTO with deleted_at
        let memberJSON = """
        {
            "id": "66666666-6666-6666-6666-666666666666",
            "name": "旧成员",
            "emoji": "👤",
            "role": "Member",
            "updated_at": "2026-07-11T12:00:00Z",
            "deleted_at": "2026-07-11T12:05:00Z"
        }
        """
        let memberDTO = try decoder.decode(MemberDTO.self, from: Data(memberJSON.utf8))
        XCTAssertTrue(memberDTO.isDeleted)
        XCTAssertEqual(memberDTO.deletedAt, parseDate("2026-07-11T12:05:00Z"))

        // 3. OrderDTO with deleted_at
        let orderJSON = """
        {
            "id": "77777777-7777-7777-7777-777777777777",
            "order_date": "2026-07-11T12:00:00Z",
            "note": "旧点单",
            "is_fulfilled": true,
            "member_id": "66666666-6666-6666-6666-666666666666",
            "updated_at": "2026-07-11T12:00:00Z",
            "deleted_at": "2026-07-11T12:05:00Z"
        }
        """
        let orderDTO = try decoder.decode(OrderDTO.self, from: Data(orderJSON.utf8))
        XCTAssertTrue(orderDTO.isDeleted)

        // 4. DiaryDTO with deleted_at
        let diaryJSON = """
        {
            "id": "88888888-8888-8888-8888-888888888888",
            "diary_date": "2026-07-11",
            "rating": 5,
            "comment": "旧日记",
            "member_id": "66666666-6666-6666-6666-666666666666",
            "dish_id": "55555555-5555-5555-5555-555555555555",
            "updated_at": "2026-07-11T12:00:00Z",
            "deleted_at": "2026-07-11T12:05:00Z"
        }
        """
        let diaryDTO = try decoder.decode(DiaryDTO.self, from: Data(diaryJSON.utf8))
        XCTAssertTrue(diaryDTO.isDeleted)
    }

    func testSupabaseManagerBuildFetchPath() {
        // Full Snapshot Path (since == nil)
        let fullPath = SupabaseManager.buildFetchPath(table: "dishes", since: nil)
        XCTAssertEqual(fullPath, "dishes?select=*")

        // Delta Path with timestamp (since != nil)
        let timestamp = parseDate("2026-07-11T12:00:00Z")
        let deltaPath = SupabaseManager.buildFetchPath(table: "dishes", since: timestamp)
        XCTAssertEqual(deltaPath, "dishes?select=*&updated_at=gt.2026-07-11T12:00:00Z")
    }

    @MainActor
    func testAppStateSyncCursorManagement() {
        let appState = AppState()
        
        // Reset Cursor
        appState.resetSyncCursor()
        XCTAssertNil(appState.lastSyncTimestamp)
        
        // Set Cursor
        let now = Date()
        appState.lastSyncTimestamp = now
        XCTAssertNotNil(appState.lastSyncTimestamp)
        XCTAssertEqual(appState.lastSyncTimestamp?.timeIntervalSince1970 ?? 0, now.timeIntervalSince1970, accuracy: 0.001)
        
        // Reset again
        appState.resetSyncCursor()
        XCTAssertNil(appState.lastSyncTimestamp)
    }

    @MainActor
    func testSyncEngineDeltaSyncInsertsAndUpdates() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let appState = AppState()
        appState.setSupabaseURL("https://mock.supabase.co")
        
        // Set existing lastSyncTimestamp -> Activates Delta Sync mode
        let baseTime = parseDate("2026-07-11T10:00:00Z")
        let newerTime = parseDate("2026-07-11T10:30:00Z")
        appState.lastSyncTimestamp = baseTime
        
        let existingDishId = UUID()
        let existingDish = Dish(id: existingDishId, name: "原菜名", category: "素菜", emoji: "🍳", updatedAt: baseTime)
        context.insert(existingDish)
        try context.save()
        
        let newDishId = UUID()
        let deltaNewDish = DishDTO(
            id: newDishId,
            name: "增量新增菜",
            category: "荤菜",
            tags: ["增量"],
            emoji: "🥩",
            dishDescription: "刚刚添加",
            ingredients: ["肉"],
            cookNote: "",
            isFavorite: false,
            imageBase64: nil,
            updatedAt: newerTime
        )
        
        let deltaUpdatedDish = DishDTO(
            id: existingDishId,
            name: "增量更新菜名",
            category: "素菜",
            tags: ["已改名"],
            emoji: "🍳",
            dishDescription: "已更新",
            ingredients: [],
            cookNote: "",
            isFavorite: true,
            imageBase64: nil,
            updatedAt: newerTime
        )
        
        SupabaseManager.shared.mockMembers = []
        SupabaseManager.shared.mockDishes = [deltaNewDish, deltaUpdatedDish]
        SupabaseManager.shared.mockOrders = []
        SupabaseManager.shared.mockDiaries = []
        
        // Run Delta Sync
        await SyncEngine.shared.syncDown(context: context, appState: appState)
        
        // Verify local SwiftData contains both the updated existing dish and the newly inserted dish
        let dishes = try context.fetch(FetchDescriptor<Dish>())
        XCTAssertEqual(dishes.count, 2)
        
        let updated = dishes.first(where: { $0.id == existingDishId })
        XCTAssertEqual(updated?.name, "增量更新菜名")
        XCTAssertEqual(updated?.isFavorite, true)
        
        let inserted = dishes.first(where: { $0.id == newDishId })
        XCTAssertEqual(inserted?.name, "增量新增菜")
        
        // Verify lastSyncTimestamp was updated
        XCTAssertNotNil(appState.lastSyncTimestamp)
        XCTAssertTrue((appState.lastSyncTimestamp ?? Date.distantPast) > baseTime)
        
        SupabaseManager.shared.mockDishes = nil
    }

    @MainActor
    func testSyncEngineDeltaSyncPrunesSoftDeletedRecords() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let appState = AppState()
        appState.setSupabaseURL("https://mock.supabase.co")
        
        let baseTime = parseDate("2026-07-11T10:00:00Z")
        let deleteTime = parseDate("2026-07-11T10:30:00Z")
        appState.lastSyncTimestamp = baseTime
        
        let dishToKeepId = UUID()
        let dishToDeleteId = UUID()
        
        let dishToKeep = Dish(id: dishToKeepId, name: "保留菜", category: "素菜", emoji: "🍳", updatedAt: baseTime)
        let dishToDelete = Dish(id: dishToDeleteId, name: "即将软删除菜", category: "荤菜", emoji: "🥩", updatedAt: baseTime)
        
        context.insert(dishToKeep)
        context.insert(dishToDelete)
        try context.save()
        
        // Remote delta returns dishToDelete with deleted_at != nil
        let deltaSoftDeletedDish = DishDTO(
            id: dishToDeleteId,
            name: "已删除",
            category: "荤菜",
            tags: [],
            emoji: "🥩",
            dishDescription: "",
            ingredients: [],
            cookNote: "",
            isFavorite: false,
            imageBase64: nil,
            updatedAt: deleteTime,
            deletedAt: deleteTime
        )
        
        SupabaseManager.shared.mockMembers = []
        SupabaseManager.shared.mockDishes = [deltaSoftDeletedDish]
        SupabaseManager.shared.mockOrders = []
        SupabaseManager.shared.mockDiaries = []
        
        // Run Delta Sync
        await SyncEngine.shared.syncDown(context: context, appState: appState)
        
        // Verify dishToDelete was pruned, dishToKeep remains
        let dishes = try context.fetch(FetchDescriptor<Dish>())
        XCTAssertEqual(dishes.count, 1)
        XCTAssertEqual(dishes.first?.id, dishToKeepId)
        
        SupabaseManager.shared.mockDishes = nil
    }

    @MainActor
    func testSyncEngineForceFullSync() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let appState = AppState()
        appState.setSupabaseURL("https://mock.supabase.co")
        appState.lastSyncTimestamp = parseDate("2026-07-11T10:00:00Z") // Had a prior cursor
        
        let staleLocalDishId = UUID()
        let remoteDishId = UUID()
        
        let staleDish = Dish(id: staleLocalDishId, name: "孤立本地菜", category: "素菜", emoji: "🍳")
        context.insert(staleDish)
        try context.save()
        
        let remoteDish = DishDTO(
            id: remoteDishId,
            name: "远端全量菜",
            category: "荤菜",
            tags: [],
            emoji: "🥩",
            dishDescription: "",
            ingredients: [],
            cookNote: "",
            isFavorite: false,
            imageBase64: nil,
            updatedAt: Date()
        )
        
        SupabaseManager.shared.mockMembers = [
            MemberDTO(id: UUID(), name: "妈妈", emoji: "👩‍🍳", role: "Cook", updatedAt: Date())
        ]
        SupabaseManager.shared.mockDishes = [remoteDish]
        SupabaseManager.shared.mockOrders = []
        SupabaseManager.shared.mockDiaries = []
        
        // Force Full Sync explicitly ignores cursor and takes full snapshot
        await SyncEngine.shared.syncDown(context: context, appState: appState, forceFullSync: true)
        
        let dishes = try context.fetch(FetchDescriptor<Dish>())
        XCTAssertEqual(dishes.count, 1)
        XCTAssertEqual(dishes.first?.id, remoteDishId)
        XCTAssertEqual(dishes.first?.name, "远端全量菜")
        
        SupabaseManager.shared.mockMembers = nil
        SupabaseManager.shared.mockDishes = nil
    }

    // MARK: - 7. Phase 3 Realtime, Outbox & Network Reachability Tests

    @MainActor
    func testNetworkMonitorStatusAndSimulation() {
        let monitor = NetworkMonitor.shared
        
        var callbackFired = false
        var lastStatus = false
        monitor.onStatusChange = { isConnected in
            callbackFired = true
            lastStatus = isConnected
        }
        
        // Simulate Offline
        monitor.simulateConnection(connected: false, cellular: false, expensive: false)
        XCTAssertFalse(monitor.isConnected)
        XCTAssertTrue(callbackFired)
        XCTAssertFalse(lastStatus)
        
        // Reset and Simulate Online via Cellular
        callbackFired = false
        monitor.simulateConnection(connected: true, cellular: true, expensive: true)
        XCTAssertTrue(monitor.isConnected)
        XCTAssertTrue(monitor.isCellular)
        XCTAssertTrue(monitor.isExpensive)
        XCTAssertTrue(callbackFired)
        XCTAssertTrue(lastStatus)
        
        // Cleanup
        monitor.onStatusChange = nil
        monitor.simulateConnection(connected: true)
    }

    @MainActor
    func testSyncOutboxEnqueuePersistenceAndClear() {
        let outbox = SyncOutbox.shared
        outbox.clear()
        XCTAssertEqual(outbox.pendingCount, 0)
        
        let dishId = UUID()
        let samplePayload = "{\"id\":\"\(dishId.uuidString)\"}".data(using: .utf8)!
        let mutation = OutboxMutation(entityId: dishId, entityType: .dish, actionType: .upsert, payload: samplePayload)
        
        outbox.enqueue(mutation)
        XCTAssertEqual(outbox.pendingCount, 1)
        XCTAssertEqual(outbox.pendingMutations.first?.entityId, dishId)
        
        // Verify load from storage creates identical queue
        let freshOutbox = SyncOutbox()
        XCTAssertEqual(freshOutbox.pendingCount, 1)
        XCTAssertEqual(freshOutbox.pendingMutations.first?.entityId, dishId)
        
        // Test clear
        outbox.clear()
        XCTAssertEqual(outbox.pendingCount, 0)
    }

    @MainActor
    func testRealtimeManagerURLDerivation() {
        // 1. PostgREST self-hosted URL (Pure HTTP REST -> returns nil to avoid handshake noise)
        let httpURL = "http://47.79.236.127:3000"
        let derivedWs = RealtimeManager.deriveWebSocketURL(from: httpURL)
        XCTAssertNil(derivedWs)
        
        // 2. Explicit WebSocket URL
        let explicitWs = "ws://47.79.236.127:3000/realtime"
        let derivedExplicit = RealtimeManager.deriveWebSocketURL(from: explicitWs)
        XCTAssertEqual(derivedExplicit?.absoluteString, "ws://47.79.236.127:3000/realtime")
        
        // 3. Supabase Cloud URL with API key
        let supabaseURL = "https://xyzcompany.supabase.co"
        let derivedWss = RealtimeManager.deriveWebSocketURL(from: supabaseURL, key: "anon_key")
        XCTAssertEqual(derivedWss?.absoluteString, "wss://xyzcompany.supabase.co/realtime/v1/websocket?apikey=anon_key&vsn=1.0.0")
    }

    @MainActor
    func testRealtimeManagerEventHandling() {
        let realtime = RealtimeManager.shared
        var eventTriggered = false
        realtime.onRemoteChange = {
            eventTriggered = true
        }
        
        realtime.simulateIncomingEvent()
        XCTAssertTrue(eventTriggered)
        XCTAssertNotNil(realtime.lastEventReceivedAt)
        
        realtime.onRemoteChange = nil
    }

    @MainActor
    func testSyncEngineOfflinePushEnqueuesToOutbox() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let appState = AppState()
        appState.resetSyncCursor()
        appState.setSupabaseURL("https://mock.supabase.co")
        
        SyncOutbox.shared.clear()
        
        // Simulate Offline
        NetworkMonitor.shared.simulateConnection(connected: false)
        
        let offlineDish = Dish(id: UUID(), name: "离线创建的菜", category: "素菜", emoji: "🥦")
        context.insert(offlineDish)
        try context.save()
        
        // Call push while offline -> Should automatically enqueue into SyncOutbox
        SyncEngine.shared.push(offlineDish, appState: appState)
        
        XCTAssertEqual(SyncOutbox.shared.pendingCount, 1)
        XCTAssertEqual(SyncOutbox.shared.pendingMutations.first?.entityType, .dish)
        XCTAssertEqual(SyncOutbox.shared.pendingMutations.first?.actionType, .upsert)
        
        // Restore Online state
        NetworkMonitor.shared.simulateConnection(connected: true)
        SyncOutbox.shared.clear()
    }

    // MARK: - 8. Supplemental Synchronization Unit Tests

    @MainActor
    func testSyncEngineDeltaSyncMembersOrdersAndDiaries() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let appState = AppState()
        appState.resetSyncCursor()
        appState.setSupabaseURL("https://mock.supabase.co")
        
        let baseTime = parseDate("2026-07-11T08:00:00Z")
        let newerTime = parseDate("2026-07-11T09:00:00Z")
        appState.lastSyncTimestamp = baseTime
        
        let memberId = UUID()
        let dishId = UUID()
        let orderId = UUID()
        let diaryId = UUID()
        
        // Initial Local State
        let member = FamilyMember(id: memberId, name: "原成员", emoji: "👨", role: "Member", updatedAt: baseTime)
        let dish = Dish(id: dishId, name: "酸辣土豆丝", category: "素菜", emoji: "🥔", updatedAt: baseTime)
        let order = MealOrder(id: orderId, member: member, dish: dish, note: "微辣", orderDate: baseTime, isFulfilled: false, updatedAt: baseTime)
        let diary = FoodDiary(id: diaryId, diaryDate: baseTime, rating: 3, comment: "一般", member: member, dish: dish, imageData: nil, updatedAt: baseTime)
        
        context.insert(member)
        context.insert(dish)
        context.insert(order)
        context.insert(diary)
        try context.save()
        
        // Remote Delta with updates
        let deltaMember = MemberDTO(id: memberId, name: "更新成员名", emoji: "👨‍🍳", role: "Cook", updatedAt: newerTime)
        let deltaOrder = OrderDTO(id: orderId, orderDate: newerTime, note: "加重辣", isFulfilled: true, memberId: memberId, dishId: dishId, updatedAt: newerTime)
        let deltaDiary = DiaryDTO(id: diaryId, diaryDate: "2026-07-11", rating: 5, comment: "超好吃！", memberId: memberId, dishId: dishId, imageBase64: nil, updatedAt: newerTime)
        
        SupabaseManager.shared.mockMembers = [deltaMember]
        SupabaseManager.shared.mockDishes = []
        SupabaseManager.shared.mockOrders = [deltaOrder]
        SupabaseManager.shared.mockDiaries = [deltaDiary]
        
        await SyncEngine.shared.syncDown(context: context, appState: appState)
        
        // Verify Member
        let fetchedMembers = try context.fetch(FetchDescriptor<FamilyMember>())
        let updatedMember = fetchedMembers.first(where: { $0.id == memberId })
        XCTAssertEqual(updatedMember?.name, "更新成员名")
        XCTAssertEqual(updatedMember?.role, "Cook")
        
        // Verify Order & Relationships
        let fetchedOrders = try context.fetch(FetchDescriptor<MealOrder>())
        let updatedOrder = fetchedOrders.first(where: { $0.id == orderId })
        XCTAssertEqual(updatedOrder?.note, "加重辣")
        XCTAssertEqual(updatedOrder?.isFulfilled, true)
        XCTAssertEqual(updatedOrder?.member?.id, memberId)
        XCTAssertEqual(updatedOrder?.dish?.id, dishId)
        
        // Verify Diary & Relationships
        let fetchedDiaries = try context.fetch(FetchDescriptor<FoodDiary>())
        let updatedDiary = fetchedDiaries.first(where: { $0.id == diaryId })
        XCTAssertEqual(updatedDiary?.rating, 5)
        XCTAssertEqual(updatedDiary?.comment, "超好吃！")
        XCTAssertEqual(updatedDiary?.member?.id, memberId)
        XCTAssertEqual(updatedDiary?.dish?.id, dishId)
        
        SupabaseManager.shared.mockMembers = nil
        SupabaseManager.shared.mockOrders = nil
        SupabaseManager.shared.mockDiaries = nil
    }

    @MainActor
    func testSyncEngineDeltaSoftDeleteMembersOrdersAndDiaries() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let appState = AppState()
        appState.resetSyncCursor()
        appState.setSupabaseURL("https://mock.supabase.co")
        
        let baseTime = parseDate("2026-07-11T08:00:00Z")
        let deleteTime = parseDate("2026-07-11T09:00:00Z")
        appState.lastSyncTimestamp = baseTime
        
        let memberId = UUID()
        let orderId = UUID()
        let diaryId = UUID()
        
        let member = FamilyMember(id: memberId, name: "待删除成员", emoji: "👤", role: "Member", updatedAt: baseTime)
        let order = MealOrder(id: orderId, note: "待删除点单", orderDate: baseTime, isFulfilled: false, updatedAt: baseTime)
        let diary = FoodDiary(id: diaryId, diaryDate: baseTime, rating: 4, comment: "待删除日记", updatedAt: baseTime)
        
        context.insert(member)
        context.insert(order)
        context.insert(diary)
        try context.save()
        
        // Delta soft delete response
        let deltaMember = MemberDTO(id: memberId, name: "已删除", emoji: "👤", role: "Member", updatedAt: deleteTime, deletedAt: deleteTime)
        let deltaOrder = OrderDTO(id: orderId, orderDate: deleteTime, note: "", isFulfilled: true, memberId: memberId, dishId: nil, updatedAt: deleteTime, deletedAt: deleteTime)
        let deltaDiary = DiaryDTO(id: diaryId, diaryDate: "2026-07-11", rating: 1, comment: "", memberId: memberId, dishId: UUID(), imageBase64: nil, updatedAt: deleteTime, deletedAt: deleteTime)
        
        SupabaseManager.shared.mockMembers = [deltaMember]
        SupabaseManager.shared.mockDishes = []
        SupabaseManager.shared.mockOrders = [deltaOrder]
        SupabaseManager.shared.mockDiaries = [deltaDiary]
        
        await SyncEngine.shared.syncDown(context: context, appState: appState)
        
        // All three must be pruned from local context
        let members = try context.fetch(FetchDescriptor<FamilyMember>())
        XCTAssertFalse(members.contains(where: { $0.id == memberId }))
        
        let orders = try context.fetch(FetchDescriptor<MealOrder>())
        XCTAssertFalse(orders.contains(where: { $0.id == orderId }))
        
        let diaries = try context.fetch(FetchDescriptor<FoodDiary>())
        XCTAssertFalse(diaries.contains(where: { $0.id == diaryId }))
        
        SupabaseManager.shared.mockMembers = nil
        SupabaseManager.shared.mockOrders = nil
        SupabaseManager.shared.mockDiaries = nil
    }

    @MainActor
    func testSyncEngineActiveMemberClearedWhenDeletedRemotely() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let appState = AppState()
        appState.resetSyncCursor()
        appState.setSupabaseURL("https://mock.supabase.co")
        
        let memberToDeleteId = UUID()
        let remainingMemberId = UUID()
        
        let memberToDelete = FamilyMember(id: memberToDeleteId, name: "被删成员", emoji: "👤")
        let remainingMember = FamilyMember(id: remainingMemberId, name: "留存成员", emoji: "👨‍🍳")
        context.insert(memberToDelete)
        context.insert(remainingMember)
        try context.save()
        
        appState.activeMemberId = memberToDeleteId
        XCTAssertEqual(appState.activeMemberId, memberToDeleteId)
        
        // Remote snapshot only contains remainingMember
        let remoteMember = MemberDTO(id: remainingMemberId, name: "留存成员", emoji: "👨‍🍳", role: "Cook", updatedAt: Date())
        SupabaseManager.shared.mockMembers = [remoteMember]
        SupabaseManager.shared.mockDishes = []
        SupabaseManager.shared.mockOrders = []
        SupabaseManager.shared.mockDiaries = []
        
        await SyncEngine.shared.syncDown(context: context, appState: appState, forceFullSync: true)
        
        // Active member should be cleanly reset to nil
        XCTAssertNil(appState.activeMemberId)
        
        SupabaseManager.shared.mockMembers = nil
    }

    @MainActor
    func testSyncEngineSilentModeVsNormalModeErrorFeedback() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let appState = AppState()
        appState.resetSyncCursor()
        appState.networkError = ""
        appState.isSyncing = false
        
        // Set invalid local port to induce immediate connection error without DNS delay
        appState.setSupabaseURL("http://127.0.0.1:65534")
        
        // 1. Silent sync: Error should NOT populate user-visible alert
        await SyncEngine.shared.syncDown(context: context, appState: appState, isSilent: true)
        XCTAssertEqual(appState.networkError, "")
        XCTAssertFalse(appState.isSyncing)
        
        // 2. Non-silent sync: Error SHOULD populate user-visible alert
        await SyncEngine.shared.syncDown(context: context, appState: appState, isSilent: false)
        XCTAssertFalse(appState.networkError.isEmpty)
        XCTAssertFalse(appState.isSyncing)
    }

    @MainActor
    func testSyncEngineEmptyRemoteSeedsDefaultMockData() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        
        let appState = AppState()
        appState.resetSyncCursor()
        appState.setSupabaseURL("https://mock.supabase.co")
        
        // Both local and remote are completely empty
        SupabaseManager.shared.mockMembers = []
        SupabaseManager.shared.mockDishes = []
        SupabaseManager.shared.mockOrders = []
        SupabaseManager.shared.mockDiaries = []
        
        await SyncEngine.shared.syncDown(context: context, appState: appState, forceFullSync: true)
        
        // Local should be seeded with SampleData
        let members = try context.fetch(FetchDescriptor<FamilyMember>())
        let dishes = try context.fetch(FetchDescriptor<Dish>())
        
        XCTAssertGreaterThan(members.count, 0)
        XCTAssertGreaterThan(dishes.count, 0)
        
        SupabaseManager.shared.mockMembers = nil
        SupabaseManager.shared.mockDishes = nil
    }

    // MARK: - 7. Food Diary & Calendar Date Robustness Tests

    func testDiaryDateParsingVariousFormats() {
        let calendar = Calendar.current
        
        // 1. yyyy-MM-dd
        let dto1 = DiaryDTO(id: UUID(), diaryDate: "2026-05-15", rating: 5, comment: "Test", memberId: UUID(), dishId: UUID(), imageBase64: nil)
        XCTAssertNotNil(dto1.parsedDiaryDate)
        if let date = dto1.parsedDiaryDate {
            XCTAssertEqual(calendar.component(.year, from: date), 2026)
            XCTAssertEqual(calendar.component(.month, from: date), 5)
            XCTAssertEqual(calendar.component(.day, from: date), 15)
        }
        
        // 2. ISO8601 with fractional seconds
        let dto2 = DiaryDTO(id: UUID(), diaryDate: "2026-04-20T08:30:00.123456Z", rating: 4, comment: "Test", memberId: UUID(), dishId: UUID(), imageBase64: nil)
        XCTAssertNotNil(dto2.parsedDiaryDate)
        
        // 3. Strict ISO8601
        let dto3 = DiaryDTO(id: UUID(), diaryDate: "2026-03-10T12:00:00Z", rating: 5, comment: "Test", memberId: UUID(), dishId: UUID(), imageBase64: nil)
        XCTAssertNotNil(dto3.parsedDiaryDate)
        
        // 4. yyyy-MM-dd HH:mm:ss
        let dto4 = DiaryDTO(id: UUID(), diaryDate: "2026-02-05 18:45:00", rating: 3, comment: "Test", memberId: UUID(), dishId: UUID(), imageBase64: nil)
        XCTAssertNotNil(dto4.parsedDiaryDate)
        if let date = dto4.parsedDiaryDate {
            XCTAssertEqual(calendar.component(.year, from: date), 2026)
            XCTAssertEqual(calendar.component(.month, from: date), 2)
            XCTAssertEqual(calendar.component(.day, from: date), 5)
        }
    }

    @MainActor
    func testFoodDiarySyncPreservesHistoricalDate() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let calendar = Calendar.current
        
        let appState = AppState()
        appState.resetSyncCursor()
        appState.setSupabaseURL("https://mock.supabase.co")
        
        let memberId = UUID()
        let dishId = UUID()
        let diaryId = UUID()
        
        let member = FamilyMember(id: memberId, name: "妈妈", emoji: "👩‍🍳", role: "Cook")
        let dish = Dish(id: dishId, name: "红烧肉", category: "荤菜", emoji: "🥩")
        context.insert(member)
        context.insert(dish)
        try context.save()
        
        // Mock remote diary with past date 2026-04-12
        let remoteDiary = DiaryDTO(
            id: diaryId,
            diaryDate: "2026-04-12",
            rating: 5,
            comment: "历史回忆",
            memberId: memberId,
            dishId: dishId,
            imageBase64: nil,
            updatedAt: Date()
        )
        
        SupabaseManager.shared.mockMembers = [MemberDTO(id: memberId, name: "妈妈", emoji: "👩‍🍳", role: "Cook")]
        SupabaseManager.shared.mockDishes = [DishDTO(id: dishId, name: "红烧肉", category: "荤菜", tags: [], emoji: "🥩", dishDescription: "", ingredients: [], cookNote: "", isFavorite: false, imageBase64: nil)]
        SupabaseManager.shared.mockOrders = []
        SupabaseManager.shared.mockDiaries = [remoteDiary]
        
        await SyncEngine.shared.syncDown(context: context, appState: appState, forceFullSync: true)
        
        let localDiaries = try context.fetch(FetchDescriptor<FoodDiary>())
        XCTAssertEqual(localDiaries.count, 1)
        
        let diary = try XCTUnwrap(localDiaries.first)
        XCTAssertEqual(diary.id, diaryId)
        XCTAssertEqual(diary.comment, "历史回忆")
        // Crucial test: Date must be April 12, 2026, NOT today!
        XCTAssertEqual(calendar.component(.year, from: diary.diaryDate), 2026)
        XCTAssertEqual(calendar.component(.month, from: diary.diaryDate), 4)
        XCTAssertEqual(calendar.component(.day, from: diary.diaryDate), 12)
        XCTAssertFalse(calendar.isDateInToday(diary.diaryDate))
        
        SupabaseManager.shared.mockMembers = nil
        SupabaseManager.shared.mockDishes = nil
        SupabaseManager.shared.mockDiaries = nil
    }
}


