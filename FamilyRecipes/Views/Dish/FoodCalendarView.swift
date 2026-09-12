import SwiftUI
import SwiftData
import PhotosUI

enum CalendarDisplayMode: Int {
    case dayDetail = 0
    case monthTimeline = 1
}

struct FoodCalendarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    @Query private var diaries: [FoodDiary]
    @Query private var orders: [MealOrder]
    
    @State private var currentMonthDate = Date() // Selected month/year
    @State private var selectedDate = Date()     // Selected day
    @State private var displayMode: CalendarDisplayMode = .dayDetail
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
    
    private var isViewingCurrentMonth: Bool {
        calendar.isDate(currentMonthDate, equalTo: Date(), toGranularity: .month)
    }
    
    // MARK: - Selected Day Data
    
    // Diaries filtered for the selected day
    var selectedDayDiaries: [FoodDiary] {
        diaries.filter { diary in
            calendar.isDate(diary.diaryDate, inSameDayAs: selectedDate)
        }
    }
    
    // Completed orders on selected date
    var selectedDayCompletedOrders: [MealOrder] {
        orders.filter { order in
            calendar.isDate(order.orderDate, inSameDayAs: selectedDate) && order.isFulfilled
        }
    }
    
    // Pending diary orders on selected date (fulfilled meal orders without diary)
    var pendingDiaryOrders: [MealOrder] {
        selectedDayCompletedOrders.filter { order in
            !diaries.contains { diary in
                calendar.isDate(diary.diaryDate, inSameDayAs: selectedDate) &&
                diary.dish?.id == order.dish?.id &&
                diary.member?.id == order.member?.id
            }
        }
    }
    
    // Other unfulfilled orders on selected date
    var selectedDayUnfulfilledOrders: [MealOrder] {
        orders.filter { order in
            calendar.isDate(order.orderDate, inSameDayAs: selectedDate) && !order.isFulfilled
        }
    }
    
    var selectedDayTotalCount: Int {
        selectedDayDiaries.count + pendingDiaryOrders.count
    }
    
    // MARK: - Month Timeline Data
    
    var monthDiaries: [FoodDiary] {
        diaries.filter { diary in
            calendar.isDate(diary.diaryDate, equalTo: currentMonthDate, toGranularity: .month)
        }
    }
    
    var monthCompletedOrders: [MealOrder] {
        orders.filter { order in
            calendar.isDate(order.orderDate, equalTo: currentMonthDate, toGranularity: .month) && order.isFulfilled
        }
    }
    
    var monthTotalRecordCount: Int {
        var count = monthDiaries.count
        for order in monthCompletedOrders {
            let hasDiary = monthDiaries.contains { diary in
                calendar.isDate(diary.diaryDate, inSameDayAs: order.orderDate) &&
                diary.dish?.id == order.dish?.id &&
                diary.member?.id == order.member?.id
            }
            if !hasDiary {
                count += 1
            }
        }
        return count
    }
    
    struct DayTimelineGroup: Identifiable {
        let date: Date
        let diaries: [FoodDiary]
        let pendingOrders: [MealOrder]
        
        var id: Date { date }
        var totalCount: Int { diaries.count + pendingOrders.count }
    }
    
    var monthGroupedRecords: [DayTimelineGroup] {
        var groups: [Date: (diaries: [FoodDiary], orders: [MealOrder])] = [:]
        
        for diary in monthDiaries {
            let dayStart = calendar.startOfDay(for: diary.diaryDate)
            var current = groups[dayStart] ?? ([], [])
            current.diaries.append(diary)
            groups[dayStart] = current
        }
        
        for order in monthCompletedOrders {
            let dayStart = calendar.startOfDay(for: order.orderDate)
            let hasDiary = (groups[dayStart]?.diaries ?? []).contains { diary in
                diary.dish?.id == order.dish?.id && diary.member?.id == order.member?.id
            }
            if !hasDiary {
                var current = groups[dayStart] ?? ([], [])
                current.orders.append(order)
                groups[dayStart] = current
            }
        }
        
        return groups.map { date, tuple in
            DayTimelineGroup(date: date, diaries: tuple.diaries, pendingOrders: tuple.orders)
        }.sorted { $0.date > $1.date }
    }
    
    // Emojis for grid representation
    private func uniqueDishEmojis(for date: Date) -> [String] {
        var emojis: [String] = []
        
        let dayDiaries = diaries.filter { calendar.isDate($0.diaryDate, inSameDayAs: date) }
        for diary in dayDiaries {
            if let emoji = diary.dish?.emoji, !emojis.contains(emoji) {
                emojis.append(emoji)
            }
        }
        
        let dayOrders = orders.filter { order in
            calendar.isDate(order.orderDate, inSameDayAs: date) && order.isFulfilled
        }
        for order in dayOrders {
            if let emoji = order.dish?.emoji, !emojis.contains(emoji) {
                emojis.append(emoji)
            }
        }
        
        return emojis
    }
    
    private func hasActivity(on date: Date) -> Bool {
        diaries.contains { calendar.isDate($0.diaryDate, inSameDayAs: date) } ||
        orders.contains { calendar.isDate($0.orderDate, inSameDayAs: date) && $0.isFulfilled }
    }
    
    // MARK: - View Body
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 18) {
                
                // 1. Month Switcher & Weekdays Row
                VStack(spacing: 12) {
                    HStack {
                        Button {
                            changeMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color(hex: "#FF5E36"))
                                .padding(8)
                                .background(Circle().fill(Color(hex: "#FF5E36").opacity(0.1)))
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Text(monthYearHeader)
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.black)
                                .foregroundColor(Color(hex: "#FF5E36"))
                            
                            if !isViewingCurrentMonth {
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        currentMonthDate = Date()
                                        selectedDate = Date()
                                    }
                                } label: {
                                    Text("回到本月")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color(hex: "#FF5E36")))
                                }
                                .buttonStyle(.plain)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            changeMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .bold))
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
                                    let hasRecord = hasActivity(on: date)
                                    
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                            selectedDate = date
                                            if displayMode == .monthTimeline {
                                                displayMode = .dayDetail
                                            }
                                        }
                                    } label: {
                                        VStack(spacing: 2) {
                                            Text("\(calendar.component(.day, from: date))")
                                                .font(.system(.subheadline, design: .rounded))
                                                .fontWeight(isSelected ? .black : (isToday ? .bold : (hasRecord ? .semibold : .medium)))
                                                .foregroundColor(isSelected ? .white : (isToday ? Color(hex: "#FF5E36") : Color(.label)))
                                            
                                            // Badges row: Emojis of dishes eaten
                                            HStack(spacing: 1) {
                                                if !dayEmojis.isEmpty {
                                                    ForEach(dayEmojis.prefix(2), id: \.self) { emoji in
                                                        Text(emoji)
                                                            .font(.system(size: 10))
                                                    }
                                                } else if hasRecord {
                                                    Circle()
                                                        .fill(isSelected ? Color.white : Color(hex: "#FF5E36"))
                                                        .frame(width: 4, height: 4)
                                                }
                                            }
                                            .frame(height: 14)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                        }
                                        .frame(height: 48)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            ZStack {
                                                if isSelected {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color(hex: "#FF5E36"))
                                                        .shadow(color: Color(hex: "#FF5E36").opacity(0.3), radius: 4, x: 0, y: 2)
                                                } else if isToday {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color(hex: "#FF5E36").opacity(0.08))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 12)
                                                                .stroke(Color(hex: "#FF5E36"), lineWidth: 1.5)
                                                        )
                                                } else if hasRecord {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color(hex: "#FF5E36").opacity(0.04))
                                                } else {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.clear)
                                                }
                                            }
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
                
                // 3. View Mode Segmented Switcher (Day Detail vs Month Timeline)
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            displayMode = .dayDetail
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.day.timeline.left")
                                .font(.caption)
                            Text("按日查看 (\(selectedDayTotalCount))")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                        }
                        .foregroundColor(displayMode == .dayDetail ? .white : Color(.secondaryLabel))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                if displayMode == .dayDetail {
                                    Capsule().fill(Color(hex: "#FF5E36"))
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            displayMode = .monthTimeline
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption)
                            Text("当月足迹 (\(monthTotalRecordCount))")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                        }
                        .foregroundColor(displayMode == .monthTimeline ? .white : Color(.secondaryLabel))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                if displayMode == .monthTimeline {
                                    Capsule().fill(Color(hex: "#FF5E36"))
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
                .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
                .padding(.horizontal, 16)
                
                // 4. Content Section Based on Mode
                if displayMode == .dayDetail {
                    dayDetailSection
                } else {
                    monthTimelineSection
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
    
    // MARK: - Mode 1: Day Detail Section
    
    private var dayDetailSection: some View {
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
                    
                    if calendar.isDateInToday(selectedDate) {
                        Text("今天还没有就餐记录或打卡日记哦\n快去点餐、做菜或者点击右上角“记一笔”吧！")
                            .font(.caption)
                            .foregroundColor(Color(.tertiaryLabel))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    } else {
                        Text("\(formattedSelectedDate()) 暂无就餐打卡记录\n您可以点击右上角“记一笔”补录当天的美食回忆！")
                            .font(.caption)
                            .foregroundColor(Color(.tertiaryLabel))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    
                    Button {
                        showingAddDiary = true
                    } label: {
                        Text("补录这一天的美食")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#FF5E36"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(hex: "#FF5E36").opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.01), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 16)
            } else {
                // 1. Pending Diary Orders (from completed meal orders)
                ForEach(pendingDiaryOrders) { order in
                    pendingOrderCard(order: order)
                }
                
                // 2. Existing diaries
                ForEach(selectedDayDiaries) { diary in
                    diaryCard(diary: diary)
                }
            }
            
            // 3. Unfulfilled orders on that day notice (if any)
            if !selectedDayUnfulfilledOrders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.badge.questionmark")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("该日有点餐尚未由掌勺人标记完成 (\(selectedDayUnfulfilledOrders.count) 道)")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Mode 2: Month Timeline Section
    
    private var monthTimelineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("📖 \(monthYearHeader) 美食足迹")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                
                Spacer()
                
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
            
            if monthGroupedRecords.isEmpty {
                VStack(spacing: 12) {
                    Text("📖")
                        .font(.system(size: 44))
                    Text("\(monthYearHeader) 暂无任何美食足迹\n点击右上角“记一笔”开始记录吧！")
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
                ForEach(monthGroupedRecords) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        // Date header badge
                        HStack(spacing: 8) {
                            Text("🗓 \(formattedTimelineDate(group.date))")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "#FF5E36"))
                            
                            Spacer()
                            
                            Text("共 \(group.totalCount) 道美味")
                                .font(.caption2)
                                .foregroundColor(Color(.secondaryLabel))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(.tertiarySystemFill)))
                        }
                        .padding(.horizontal, 4)
                        
                        ForEach(group.pendingOrders) { order in
                            pendingOrderCard(order: order)
                        }
                        
                        ForEach(group.diaries) { diary in
                            diaryCard(diary: diary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                }
            }
        }
    }
    
    // MARK: - Reusable Cards
    
    private func pendingOrderCard(order: MealOrder) -> some View {
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
                    selectedDate = order.orderDate
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
                if let data = order.dish?.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Text(order.dish?.emoji ?? "🍲")
                        .font(.title)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                }
                
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
    }
    
    private func diaryCard(diary: FoodDiary) -> some View {
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
                if let data = diary.dish?.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Text(diary.dish?.emoji ?? "🍲")
                        .font(.largeTitle)
                        .frame(width: 50, height: 50)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(diary.dish?.name ?? "未知菜品")
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.bold)
                    
                    // Subtle tag styling
                    Text(diary.dish?.category ?? "其他")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "#FF5E36"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(hex: "#FF5E36").opacity(0.08)))
                }
                Spacer()
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Review Comments
            if !diary.comment.isEmpty {
                Text("💬 “\(diary.comment)”")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(Color(.secondaryLabel))
                    .lineSpacing(4)
                    .padding(.horizontal, 4)
            }
            
            // Review Photo attachment (Clean image border overlay)
            if let data = diary.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .onTapGesture {
                        selectedDiaryForImage = diary
                    }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.015), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Helpers & Actions
    
    // Switch Month with automatic date selection linkage
    private func changeMonth(by val: Int) {
        if let newDate = calendar.date(byAdding: .month, value: val, to: currentMonthDate) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                currentMonthDate = newDate
                
                // If switching back to current month, select today
                if calendar.isDate(newDate, equalTo: Date(), toGranularity: .month) {
                    selectedDate = Date()
                } else {
                    // Check if any day in new month has records, select that date, otherwise 1st of month
                    let recordDates = getDatesWithRecords(in: newDate)
                    selectedDate = recordDates.first ?? calendar.date(from: calendar.dateComponents([.year, .month], from: newDate)) ?? newDate
                }
            }
        }
    }
    
    private func getDatesWithRecords(in monthDate: Date) -> [Date] {
        var recordDates: Set<Date> = []
        for diary in diaries {
            if calendar.isDate(diary.diaryDate, equalTo: monthDate, toGranularity: .month) {
                let startOfDay = calendar.startOfDay(for: diary.diaryDate)
                recordDates.insert(startOfDay)
            }
        }
        for order in orders where order.isFulfilled {
            if calendar.isDate(order.orderDate, equalTo: monthDate, toGranularity: .month) {
                let startOfDay = calendar.startOfDay(for: order.orderDate)
                recordDates.insert(startOfDay)
            }
        }
        return recordDates.sorted(by: <)
    }
    
    private func formattedSelectedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        if calendar.isDateInToday(selectedDate) {
            return "今天 (\(formatter.string(from: selectedDate)))"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "昨天 (\(formatter.string(from: selectedDate)))"
        }
        return formatter.string(from: selectedDate)
    }
    
    private func formattedTimelineDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 · EEEE"
        if calendar.isDateInToday(date) {
            return "今天 · \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "昨天 · \(formatter.string(from: date))"
        }
        return formatter.string(from: date)
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
        let diaryId = diary.id
        modelContext.delete(diary)
        SyncEngine.shared.deleteDiary(id: diaryId, appState: appState)
    }
}

// MARK: - Add Diary Bottom Sheet

struct AddDiarySheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allDishes: [Dish]
    @Query private var allOrders: [MealOrder]
    @Query private var members: [FamilyMember]
    
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
        let todayCompletedOrders = allOrders.filter { order in
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
            return allDishes
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
                                            ZStack {
                                                if let data = dish.imageData, let uiImage = UIImage(data: data) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 48, height: 48)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                } else {
                                                    Text(dish.emoji)
                                                        .font(.system(size: 32))
                                                        .frame(width: 48, height: 48)
                                                }
                                            }
                                            Text(dish.name)
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 84, height: 84)
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
                        
                        // Selected dish preview banner
                        if let dish = selectedDish {
                            HStack(spacing: 12) {
                                if let data = dish.imageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    Text(dish.emoji)
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#FF5E36").opacity(0.1)))
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(dish.name)
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.bold)
                                        
                                        Text(dish.category)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Color(hex: "#FF5E36"))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color(hex: "#FF5E36").opacity(0.1)))
                                    }
                                    
                                    if !dish.dishDescription.isEmpty {
                                        Text(dish.dishDescription)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                            }
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(14)
                            .padding(.vertical, 4)
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
        guard let activeMemberId = appState.activeMemberId,
              let member = members.first(where: { $0.id == activeMemberId }) else {
            saveErrorMessage = "请先选择您的家庭角色！"
            return
        }
        
        // Downscale image if needed for storage
        var finalImageData: Data? = nil
        if let data = imageData, let compressedBase64 = compressImageToBase64(data) {
            finalImageData = Data(base64Encoded: compressedBase64)
        }
        
        let newDiary = FoodDiary(
            diaryDate: diaryDate,
            rating: rating,
            comment: comment,
            member: member,
            dish: dish,
            imageData: finalImageData ?? imageData
        )
        
        modelContext.insert(newDiary)
        SyncEngine.shared.push(newDiary, appState: appState)
        dismiss()
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
