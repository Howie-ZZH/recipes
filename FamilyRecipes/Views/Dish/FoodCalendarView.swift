import SwiftUI
import PhotosUI

struct FoodCalendarView: View {
    @Environment(AppState.self) private var appState
    
    @State private var currentMonthDate = Date() // Selected month/year
    @State private var selectedDate = Date()     // Selected day
    @State private var showingAddDiary = false
    @State private var preselectedDishForDiary: Dish? = nil
    @State private var selectedDiaryForImage: FoodDiary?
    
    private let calendar = Calendar.current
    
    // Header formatting
    private var monthYearHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: currentMonthDate)
    }
    
    // Diaries filtered for the selected day
    var selectedDayDiaries: [FoodDiary] {
        appState.diaries.filter { diary in
            calendar.isDate(diary.diaryDate, inSameDayAs: selectedDate)
        }
    }
    
    // Completed orders on selected date
    var selectedDayCompletedOrders: [MealOrder] {
        appState.orders.filter { order in
            calendar.isDate(order.orderDate, inSameDayAs: selectedDate) && order.isFulfilled
        }
    }
    
    // Completed orders that don't have a diary entry yet on the selected day
    var pendingDiaryOrders: [MealOrder] {
        selectedDayCompletedOrders.filter { order in
            !appState.diaries.contains { diary in
                calendar.isDate(diary.diaryDate, inSameDayAs: selectedDate) &&
                diary.dishId == order.dishId &&
                diary.memberId == order.memberId
            }
        }
    }
    
    // Emojis for grid representation
    private func uniqueDishEmojis(for date: Date) -> [String] {
        var emojis: [String] = []
        
        let dayDiaries = appState.diaries.filter { calendar.isDate($0.diaryDate, inSameDayAs: date) }
        for diary in dayDiaries {
            if let emoji = diary.dish?.emoji, !emojis.contains(emoji) {
                emojis.append(emoji)
            }
        }
        
        let dayOrders = appState.orders.filter { order in
            calendar.isDate(order.orderDate, inSameDayAs: date) && order.isFulfilled
        }
        for order in dayOrders {
            if let emoji = order.dish?.emoji, !emojis.contains(emoji) {
                emojis.append(emoji)
            }
        }
        
        return emojis
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                
                // 1. Month Switcher & Weekdays Row
                VStack(spacing: 12) {
                    HStack {
                        Button {
                            changeMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "#FF5E36"))
                                .padding(8)
                                .background(Circle().fill(Color(hex: "#FF5E36").opacity(0.1)))
                        }
                        
                        Spacer()
                        
                        Text(monthYearHeader)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.black)
                            .foregroundColor(Color(hex: "#FF5E36"))
                        
                        Spacer()
                        
                        Button {
                            changeMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "#FF5E36"))
                                .padding(8)
                                .background(Circle().fill(Color(hex: "#FF5E36").opacity(0.1)))
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Weekday names
                    HStack {
                        ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                            Text(day)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(Color(.secondaryLabel))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.top, 16)
                
                // 2. Calendar Month Days Grid
                VStack(spacing: 6) {
                    let daysGrid = generateDaysInMonth(for: currentMonthDate)
                    let rows = daysGrid.chunked(into: 7)
                    
                    ForEach(0..<rows.count, id: \.self) { rowIndex in
                        HStack(spacing: 6) {
                            ForEach(rows[rowIndex], id: \.self) { dayDate in
                                if let date = dayDate {
                                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                                    let isToday = calendar.isDateInToday(date)
                                    let dayEmojis = uniqueDishEmojis(for: date)
                                    
                                    Button {
                                        selectedDate = date
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text("\(calendar.component(.day, from: date))")
                                                .font(.system(.subheadline, design: .rounded))
                                                .fontWeight(isSelected ? .black : (isToday ? .bold : .medium))
                                                .foregroundColor(isSelected ? .white : (isToday ? Color(hex: "#FF5E36") : Color(.label)))
                                            
                                            // Badges row: Emojis of dishes eaten
                                            HStack(spacing: 1) {
                                                if !dayEmojis.isEmpty {
                                                    ForEach(dayEmojis.prefix(2), id: \.self) { emoji in
                                                        Text(emoji)
                                                            .font(.system(size: 10))
                                                    }
                                                } else {
                                                    Spacer()
                                                        .frame(height: 12)
                                                }
                                            }
                                        }
                                        .frame(height: 48)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(isSelected ? Color(hex: "#FF5E36") : (isToday ? Color(hex: "#FF5E36").opacity(0.12) : Color.clear))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    // Empty padding cell
                                    Color.clear
                                        .frame(height: 48)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .shadow(color: Color.black.opacity(0.015), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 16)
                
                // 3. Diaries Section List
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("📅 \(formattedSelectedDate()) 记录")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Add Diary Button
                        Button {
                            showingAddDiary = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text("记一笔")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color(hex: "#FF5E36")))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    
                    if selectedDayDiaries.isEmpty && pendingDiaryOrders.isEmpty {
                        VStack(spacing: 12) {
                            Text("🥗")
                                .font(.system(size: 44))
                            Text("今天还没有就餐记录或打卡日记哦\n快去点餐、做菜或者点击右上角“记一笔”吧！")
                                .font(.caption)
                                .foregroundColor(Color(.tertiaryLabel))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(22)
                        .shadow(color: Color.black.opacity(0.01), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 16)
                    } else {
                        // 1. Pending Diary Orders (from completed meal orders)
                        ForEach(pendingDiaryOrders) { order in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Text(order.member?.emoji ?? "👤")
                                        .font(.title3)
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill(Color(hex: "#FF5E36").opacity(0.1)))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(order.member?.name ?? "家庭成员")
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.bold)
                                        Text("🍳 掌勺人已制作完成这道菜")
                                            .font(.caption2)
                                            .foregroundColor(Color(.secondaryLabel))
                                    }
                                    
                                    Spacer()
                                    
                                    // Rate/Review Button
                                    Button {
                                        preselectedDishForDiary = order.dish
                                        showingAddDiary = true
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "star.bubble.fill")
                                                .font(.caption)
                                            Text("写就餐评价")
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Color(hex: "#FF5E36")))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                HStack(spacing: 12) {
                                    Text(order.dish?.emoji ?? "🍲")
                                        .font(.title)
                                        .frame(width: 44, height: 44)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(order.dish?.name ?? "未知菜品")
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.bold)
                                        Text(order.dish?.category ?? "其他")
                                            .font(.caption2)
                                            .foregroundColor(Color(.secondaryLabel))
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(Color(.secondarySystemBackground).opacity(0.6))
                                .cornerRadius(12)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color(hex: "#FF5E36").opacity(0.3), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, miterLimit: 10, dash: [4, 4]))
                                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: "#FF5E36").opacity(0.03)))
                            )
                            .padding(.horizontal, 16)
                        }
                        
                        // 2. Existing diaries
                        ForEach(selectedDayDiaries) { diary in
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 10) {
                                    // Author Info
                                    Text(diary.member?.emoji ?? "👤")
                                        .font(.title2)
                                        .frame(width: 38, height: 38)
                                        .background(Circle().fill(Color(hex: "#FF5E36").opacity(0.1)))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(diary.member?.name ?? "未知家庭成员")
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.bold)
                                        
                                        // Rating Stars
                                        HStack(spacing: 2) {
                                            ForEach(1...5, id: \.self) { star in
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(star <= diary.rating ? .orange : Color(.systemGray4))
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Delete Diary Action
                                    Button {
                                        deleteDiary(diary)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.footnote)
                                            .foregroundColor(.red)
                                            .padding(8)
                                            .background(Circle().fill(Color.red.opacity(0.08)))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // Food Card row
                                HStack(spacing: 12) {
                                    Text(diary.dish?.emoji ?? "🍲")
                                        .font(.largeTitle)
                                        .frame(width: 50, height: 50)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(diary.dish?.name ?? "未知菜品")
                                            .font(.system(.body, design: .rounded))
                                            .fontWeight(.bold)
                                        Text(diary.dish?.category ?? "其他")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(Color(hex: "#FF5E36")))
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)
                                
                                // Review Comments
                                if !diary.comment.isEmpty {
                                    Text("💬 “\(diary.comment)”")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(Color(.secondaryLabel))
                                        .lineSpacing(4)
                                        .padding(.horizontal, 4)
                                }
                                
                                // Review Photo attachment
                                if let data = diary.imageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 180)
                                        .frame(maxWidth: .infinity)
                                        .cornerRadius(16)
                                        .clipped()
                                        .onTapGesture {
                                            selectedDiaryForImage = diary
                                        }
                                }
                            }
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(22)
                            .shadow(color: Color.black.opacity(0.015), radius: 8, x: 0, y: 4)
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingAddDiary, onDismiss: { preselectedDishForDiary = nil }) {
            AddDiarySheet(diaryDate: selectedDate, initialDish: preselectedDishForDiary)
                .environment(appState)
        }
        .fullScreenCover(item: $selectedDiaryForImage) { diary in
            FullScreenImageViewer(imageData: diary.imageData)
        }
    }
    
    // Switch Month
    private func changeMonth(by val: Int) {
        if let newDate = calendar.date(byAdding: .month, value: val, to: currentMonthDate) {
            withAnimation(.spring()) {
                currentMonthDate = newDate
            }
        }
    }
    
    private func formattedSelectedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        if calendar.isDateInToday(selectedDate) {
            return "今天 (\(formatter.string(from: selectedDate)))"
        }
        return formatter.string(from: selectedDate)
    }
    
    // Generate dates representing the full grid of a monthly calendar
    private func generateDaysInMonth(for date: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return [] }
        
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let firstOfMonth = calendar.date(from: components) else { return [] }
        let startWeekday = calendar.component(.weekday, from: firstOfMonth) - 1 // 0-indexed Sun
        
        var days: [Date?] = []
        // Padding prefix
        for _ in 0..<startWeekday {
            days.append(nil)
        }
        
        // Days
        for day in 1...range.count {
            if let targetDate = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(targetDate)
            }
        }
        
        // Padding suffix to align full row (7-cols)
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func deleteDiary(_ diary: FoodDiary) {
        Task {
            do {
                try await appState.deleteDiary(id: diary.id)
            } catch {
                print("Failed to delete diary: \(error)")
            }
        }
    }
}

// MARK: - Add Diary Bottom Sheet

struct AddDiarySheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    let diaryDate: Date
    let initialDish: Dish?
    
    @State private var selectedDish: Dish?
    @State private var rating = 5
    @State private var comment = ""
    
    // Image selection state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isSaving = false
    @State private var saveErrorMessage = ""
    @State private var searchDishQuery = ""
    @State private var showAllRecipes = false
    
    init(diaryDate: Date, initialDish: Dish? = nil) {
        self.diaryDate = diaryDate
        self.initialDish = initialDish
        self._selectedDish = State(initialValue: initialDish)
    }
    
    // Get unique dishes prepared/completed on the selected date
    var completedDishesForDate: [Dish] {
        let calendar = Calendar.current
        let todayCompletedOrders = appState.orders.filter { order in
            calendar.isDate(order.orderDate, inSameDayAs: diaryDate) && order.isFulfilled
        }
        var uniqueDishes: [Dish] = []
        for order in todayCompletedOrders {
            if let dish = order.dish, !uniqueDishes.contains(where: { $0.id == dish.id }) {
                uniqueDishes.append(dish)
            }
        }
        return uniqueDishes
    }
    
    var availableDishes: [Dish] {
        if completedDishesForDate.isEmpty || showAllRecipes {
            return appState.dishes
        } else {
            return completedDishesForDate
        }
    }
    
    // Filter dishes based on search query
    var filteredDishes: [Dish] {
        if searchDishQuery.isEmpty {
            return availableDishes
        }
        return availableDishes.filter {
            $0.name.localizedCaseInsensitiveContains(searchDishQuery) ||
            $0.category.localizedCaseInsensitiveContains(searchDishQuery)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: HStack {
                    Text(completedDishesForDate.isEmpty || showAllRecipes ? "第一步：选择您吃的菜品" : "第一步：选择今日已做菜品")
                    Spacer()
                    if !completedDishesForDate.isEmpty {
                        Button(showAllRecipes ? "只看今日已做" : "显示全部菜谱") {
                            withAnimation(.spring()) {
                                showAllRecipes.toggle()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(Color(hex: "#FF5E36"))
                        .textCase(nil)
                    }
                }) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(.secondaryLabel))
                        TextField("搜索菜名、分类...", text: $searchDishQuery)
                    }
                    .padding(.vertical, 2)
                    
                    if filteredDishes.isEmpty {
                        Text("没有搜到匹配菜品，先在菜谱里增加吧！")
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                            .padding(.vertical, 8)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(filteredDishes) { dish in
                                    Button {
                                        withAnimation(.spring()) {
                                            selectedDish = dish
                                        }
                                    } label: {
                                        VStack(spacing: 6) {
                                            Text(dish.emoji)
                                                .font(.system(size: 32))
                                            Text(dish.name)
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 80, height: 80)
                                        .background(selectedDish?.id == dish.id ? Color(hex: "#FF5E36").opacity(0.12) : Color(.secondarySystemBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(selectedDish?.id == dish.id ? Color(hex: "#FF5E36") : Color.clear, lineWidth: 2)
                                        )
                                        .cornerRadius(16)
                                        .foregroundColor(selectedDish?.id == dish.id ? Color(hex: "#FF5E36") : Color(.label))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                
                Section("第二步：打分与感言") {
                    // Rating stars
                    HStack(spacing: 8) {
                        Text("美味评分")
                            .font(.subheadline)
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    rating = star
                                } label: {
                                    Image(systemName: "star.fill")
                                        .font(.title3)
                                        .foregroundColor(star <= rating ? .orange : Color(.systemGray4))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // Comment TextEditor
                    TextEditor(text: $comment)
                        .frame(height: 80)
                        .overlay(
                            Group {
                                if comment.isEmpty {
                                    Text("写下您对这餐美食的真实吃后感言（如：红烧肉肥而不腻，分量非常足，太棒啦！）...")
                                        .foregroundColor(Color(.placeholderText))
                                        .font(.subheadline)
                                        .padding(.leading, 4)
                                        .padding(.top, 8)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                Section("第三步：实拍菜品图 (选填)") {
                    HStack(spacing: 16) {
                        if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .cornerRadius(12)
                                .clipped()
                                .overlay(
                                    Button {
                                        withAnimation {
                                            self.imageData = nil
                                            self.selectedPhotoItem = nil
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .background(Circle().fill(Color.white))
                                    }
                                    .buttonStyle(.plain)
                                    .offset(x: 35, y: -35)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(Color(.secondaryLabel))
                                        .font(.title2)
                                )
                        }
                        
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("上传菜品实拍")
                            }
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "#FF5E36"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(hex: "#FF5E36").opacity(0.1)))
                        }
                        .buttonStyle(.borderless)
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    await MainActor.run {
                                        withAnimation {
                                            self.imageData = data
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("记录今天吃什么")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FF5E36"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveDiary()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存记录")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(Color(hex: "#FF5E36"))
                    .disabled(selectedDish == nil || isSaving)
                }
            }
            .overlay(
                Group {
                    if !saveErrorMessage.isEmpty {
                        VStack {
                            Spacer()
                            Text(saveErrorMessage)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Capsule().fill(Color.red.opacity(0.9)))
                                .padding(.bottom, 20)
                        }
                    }
                }
            )
        }
    }
    
    private func saveDiary() {
        guard let dish = selectedDish else { return }
        guard let member = appState.currentMember else {
            saveErrorMessage = "请先选择您的家庭角色！"
            return
        }
        
        isSaving = true
        saveErrorMessage = ""
        
        Task {
            // Compress image to Base64 to save storage space
            var base64String: String? = nil
            if let imageData = imageData {
                base64String = compressImageToBase64(imageData)
            }
            
            let newDiary = FoodDiary(
                id: UUID(),
                diaryDate: diaryDate,
                rating: rating,
                comment: comment,
                memberId: member.id,
                dishId: dish.id,
                imageBase64: base64String
            )
            
            do {
                try await appState.addDiary(newDiary)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveErrorMessage = "保存失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Scale and compress raw photo data to limit payload size
    private func compressImageToBase64(_ data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        
        let maxDimension: CGFloat = 800
        var newSize = image.size
        if image.size.width > maxDimension || image.size.height > maxDimension {
            if image.size.width > image.size.height {
                newSize = CGSize(width: maxDimension, height: image.size.height * (maxDimension / image.size.width))
            } else {
                newSize = CGSize(width: image.size.width * (maxDimension / image.size.height), height: maxDimension)
            }
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let compressedData = resizedImage?.jpegData(compressionQuality: 0.5) else { return nil }
        return compressedData.base64EncodedString()
    }
}

// MARK: - Extension Helper

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
