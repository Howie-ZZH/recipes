import SwiftUI
import SwiftData

struct CookDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var allOrders: [MealOrder]
    
    @State private var dashboardMode = 0 // 0: 今日菜品, 1: 智能买菜清单
    @State private var checkedIngredients: Set<String> = []
    @Namespace private var segmentNamespace
    
    var todayOrders: [MealOrder] {
        let calendar = Calendar.current
        return allOrders.filter { calendar.isDateInToday($0.orderDate) }
    }
    
    // Active today orders from AppState memory
    var activeOrders: [MealOrder] {
        todayOrders.filter { !$0.isFulfilled }
    }
    
    // Completed today orders from AppState memory
    var completedOrders: [MealOrder] {
        todayOrders.filter { $0.isFulfilled }
    }
    
    // Active past orders (unfulfilled orders before today)
    var pastPendingOrders: [MealOrder] {
        let calendar = Calendar.current
        return allOrders.filter { !calendar.isDateInToday($0.orderDate) && !$0.isFulfilled }
            .sorted { $0.orderDate > $1.orderDate }
    }
    
    // Group active orders by dish
    var groupedActiveOrders: [DishGroupedOrder] {
        var groups: [UUID: DishGroupedOrder] = [:]
        for order in activeOrders {
            guard let dish = order.dish else { continue }
            if var group = groups[dish.id] {
                group.orders.append(order)
                groups[dish.id] = group
            } else {
                groups[dish.id] = DishGroupedOrder(dish: dish, orders: [order])
            }
        }
        return Array(groups.values).sorted { $0.orders.count > $1.orders.count }
    }
    
    // Group completed orders by dish
    var groupedCompletedOrders: [DishGroupedOrder] {
        var groups: [UUID: DishGroupedOrder] = [:]
        for order in completedOrders {
            guard let dish = order.dish else { continue }
            if var group = groups[dish.id] {
                group.orders.append(order)
                groups[dish.id] = group
            } else {
                groups[dish.id] = DishGroupedOrder(dish: dish, orders: [order])
            }
        }
        return Array(groups.values).sorted { $0.orders.count > $1.orders.count }
    }
    
    // Extract ingredients from active orders and aggregate them
    var shoppingList: [String] {
        var items: [String] = []
        for order in activeOrders {
            if let dish = order.dish {
                items.append(contentsOf: dish.ingredients)
            }
        }
        // Remove duplicates but keep order roughly
        var uniqueItems: [String] = []
        for item in items {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !uniqueItems.contains(trimmed) {
                uniqueItems.append(trimmed)
            }
        }
        return uniqueItems
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Sub-navigation segmented controller
            HStack(spacing: 0) {
                ForEach(0..<2) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dashboardMode = mode
                        }
                    } label: {
                        Text(mode == 0 ? "🍳 今日菜单 (\(activeOrders.count))" : "🛒 自动买菜单 (\(shoppingList.count))")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(dashboardMode == mode ? .white : Color(.secondaryLabel))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .background(
                        ZStack {
                            if dashboardMode == mode {
                                Capsule()
                                    .fill(Color(hex: "#FF5E36"))
                                    .matchedGeometryEffect(id: "activeSegment", in: segmentNamespace)
                            }
                        }
                    )
                }
            }
            .padding(4)
            .background(Capsule().fill(Color(.secondarySystemBackground)))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if dashboardMode == 0 {
                // TODAY'S DISH PREPARATION WORKSPACE
                if groupedActiveOrders.isEmpty && groupedCompletedOrders.isEmpty && pastPendingOrders.isEmpty {
                    VStack(spacing: 24) {
                        Spacer()
                        Text("🧑‍🍳")
                            .font(.system(size: 64))
                        Text("今天还没有人点餐哦！")
                            .font(.subheadline)
                            .foregroundColor(Color(.secondaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                } else {
                    List {
                        // 1. Pending Section
                        if !groupedActiveOrders.isEmpty {
                            Section(header: Text("🍳 待制作菜品 (\(activeOrders.count))")
                                .font(.system(.footnote, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "#FF5E36"))
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                            ) {
                                ForEach(groupedActiveOrders) { group in
                                    VStack(alignment: .leading, spacing: 14) {
                                        HStack {
                                            if let data = group.dish.imageData, let uiImage = UIImage(data: data) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 38, height: 38)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            } else {
                                                Text(group.dish.emoji)
                                                    .font(.title2)
                                                    .frame(width: 38, height: 38)
                                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemFill)))
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 8) {
                                                    Text(group.dish.name)
                                                        .font(.headline)
                                                    
                                                    let totalCount = todayOrders.filter { $0.dish?.id == group.dish.id }.count
                                                    let fulfilledCount = todayOrders.filter { $0.dish?.id == group.dish.id && $0.isFulfilled }.count
                                                    Text("\(fulfilledCount) / \(totalCount) 已做")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(.green)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 2)
                                                        .background(Capsule().fill(Color.green.opacity(0.12)))
                                                }
                                                Text(group.dish.category)
                                                    .font(.caption2)
                                                    .foregroundColor(Color(hex: "#FF5E36"))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 1)
                                                    .background(Capsule().fill(Color(hex: "#FF5E36").opacity(0.12)))
                                            }
                                            
                                            Spacer()
                                            
                                            // Complete group button
                                            Button {
                                                completeDish(group: group)
                                            } label: {
                                                Text("制作完成")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(Color.green)
                                                    .cornerRadius(12)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        
                                        Divider()
                                        
                                        // Detail requests per person
                                        VStack(alignment: .leading, spacing: 10) {
                                            ForEach(group.orders) { order in
                                                HStack(alignment: .top, spacing: 8) {
                                                    Text(order.member?.emoji ?? "👤")
                                                        .font(.subheadline)
                                                        .frame(width: 24, height: 24)
                                                        .background(Circle().fill(Color.orange.opacity(0.15)))
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(order.member?.name ?? "未知成员")
                                                            .font(.system(.subheadline, design: .rounded))
                                                            .fontWeight(.semibold)
                                                        
                                                        if !order.note.isEmpty {
                                                            Text("💬 \"\(order.note)\"")
                                                                .font(.system(.caption, design: .rounded))
                                                                .foregroundColor(Color(hex: "#FF5E36"))
                                                                .italic()
                                                        }
                                                    }
                                                    Spacer()
                                                    
                                                    Button {
                                                        completeSingleOrder(order: order)
                                                    } label: {
                                                        Image(systemName: "circle")
                                                            .foregroundColor(Color(hex: "#FF5E36"))
                                                            .font(.title3)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                    }
                                    .padding(16)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(20)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        
                        // 2. Past Pending Section (if any)
                        if !pastPendingOrders.isEmpty {
                            Section(header: HStack {
                                Text("⚠️ 往期未完成点餐 (\(pastPendingOrders.count))")
                                    .font(.system(.footnote, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                
                                Spacer()
                                
                                Button("全部补做完成") {
                                    completeAllPastOrders()
                                }
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "#FF5E36"))
                            }
                            .padding(.top, 14)
                            .padding(.bottom, 4)
                            ) {
                                ForEach(pastPendingOrders) { order in
                                    HStack(spacing: 12) {
                                        if let data = order.dish?.imageData, let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 38, height: 38)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        } else {
                                            Text(order.dish?.emoji ?? "🍲")
                                                .font(.title2)
                                                .frame(width: 38, height: 38)
                                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(order.dish?.name ?? "未知菜品")
                                                    .font(.system(.subheadline, design: .rounded))
                                                    .fontWeight(.bold)
                                                
                                                Text(formattedOrderDate(order.orderDate))
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(.secondary)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                                            }
                                            
                                            HStack(spacing: 4) {
                                                Text(order.member?.emoji ?? "👤")
                                                    .font(.caption2)
                                                Text(order.member?.name ?? "未知成员")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                
                                                if !order.note.isEmpty {
                                                    Text("💬 \"\(order.note)\"")
                                                        .font(.caption2)
                                                        .foregroundColor(Color(hex: "#FF5E36"))
                                                        .italic()
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            completeSingleOrder(order: order)
                                        } label: {
                                            Text("补做完成")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.green)
                                                .cornerRadius(10)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(14)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(16)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .padding(.vertical, 3)
                                }
                            }
                        }
                        
                        // 3. Completed Section
                        if !groupedCompletedOrders.isEmpty {
                            Section(header: Text("✅ 今日已制作 (\(completedOrders.count))")
                                .font(.system(.footnote, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(Color(.secondaryLabel))
                                .padding(.top, 14)
                                .padding(.bottom, 4)
                            ) {
                                ForEach(groupedCompletedOrders) { group in
                                    VStack(alignment: .leading, spacing: 14) {
                                        HStack {
                                            if let data = group.dish.imageData, let uiImage = UIImage(data: data) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 38, height: 38)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    .opacity(0.6)
                                            } else {
                                                Text(group.dish.emoji)
                                                    .font(.title2)
                                                    .frame(width: 38, height: 38)
                                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemFill)))
                                                    .opacity(0.6)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 8) {
                                                    Text(group.dish.name)
                                                        .font(.headline)
                                                        .strikethrough()
                                                        .foregroundColor(Color(.secondaryLabel))
                                                    
                                                    let totalCount = todayOrders.filter { $0.dish?.id == group.dish.id }.count
                                                    let fulfilledCount = todayOrders.filter { $0.dish?.id == group.dish.id && $0.isFulfilled }.count
                                                    Text("\(fulfilledCount) / \(totalCount) 已做")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(.green)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 2)
                                                        .background(Capsule().fill(Color.green.opacity(0.12)))
                                                }
                                                Text(group.dish.category)
                                                    .font(.caption2)
                                                    .foregroundColor(Color(.secondaryLabel))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 1)
                                                    .background(Capsule().fill(Color(.systemGray5)))
                                            }
                                            
                                            Spacer()
                                            
                                            // Revert group button
                                            Button {
                                                revertDish(group: group)
                                            } label: {
                                                Text("撤回")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(Color(hex: "#FF5E36"))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(Capsule().stroke(Color(hex: "#FF5E36"), lineWidth: 1.5))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        
                                        Divider()
                                        
                                        // Detail requests per person
                                        VStack(alignment: .leading, spacing: 10) {
                                            ForEach(group.orders) { order in
                                                HStack(alignment: .top, spacing: 8) {
                                                    Text(order.member?.emoji ?? "👤")
                                                        .font(.subheadline)
                                                        .frame(width: 24, height: 24)
                                                        .background(Circle().fill(Color(.systemGray6)))
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(order.member?.name ?? "未知成员")
                                                            .font(.system(.subheadline, design: .rounded))
                                                            .fontWeight(.semibold)
                                                            .foregroundColor(Color(.secondaryLabel))
                                                        
                                                        if !order.note.isEmpty {
                                                            Text("💬 \"\(order.note)\"")
                                                                .font(.system(.caption, design: .rounded))
                                                                .foregroundColor(Color(.tertiaryLabel))
                                                                .italic()
                                                        }
                                                    }
                                                    Spacer()
                                                    
                                                    Button {
                                                        revertSingleOrder(order: order)
                                                    } label: {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundColor(.green)
                                                            .font(.title3)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                    }
                                    .padding(16)
                                    .background(Color(.secondarySystemGroupedBackground).opacity(0.85))
                                    .cornerRadius(20)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color(.systemGroupedBackground))
                }
            } else {
                // AUTOMATED SMART SHOPPING LIST
                if shoppingList.isEmpty {
                    VStack(spacing: 24) {
                        Spacer()
                        Text("🛒")
                            .font(.system(size: 64))
                        Text("点餐列表为空，买菜清单也空空如也。")
                            .font(.subheadline)
                            .foregroundColor(Color(.secondaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title header for list
                        HStack {
                            Text("买菜清单汇总")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(Color(.secondaryLabel))
                            Spacer()
                            Button("清空选定") {
                                withAnimation {
                                    checkedIngredients.removeAll()
                                }
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#FF5E36"))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 8)
                        
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(shoppingList, id: \.self) { ingredient in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if checkedIngredients.contains(ingredient) {
                                                checkedIngredients.remove(ingredient)
                                            } else {
                                                checkedIngredients.insert(ingredient)
                                            }
                                        }
                                    } label: {
                                        let isChecked = checkedIngredients.contains(ingredient)
                                        HStack(spacing: 14) {
                                            ZStack {
                                                Image(systemName: "circle")
                                                    .font(.title3)
                                                    .foregroundColor(Color(hex: "#FF5E36"))
                                                    .scaleEffect(isChecked ? 0.8 : 1.0)
                                                    .opacity(isChecked ? 0.0 : 1.0)
                                                
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundColor(.green)
                                                    .scaleEffect(isChecked ? 1.0 : 0.8)
                                                    .opacity(isChecked ? 1.0 : 0.0)
                                            }
                                            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isChecked)
                                            
                                            Text(ingredient)
                                                .font(.system(.body, design: .rounded))
                                                .foregroundColor(isChecked ? Color(.tertiaryLabel) : Color(.label))
                                                .strikethrough(isChecked, color: Color(.tertiaryLabel))
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(Color(.secondarySystemGroupedBackground))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(ScaledButtonStyle())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await SyncEngine.shared.syncDown(context: modelContext, appState: appState)
        }
        .task {
            await SyncEngine.shared.syncDown(context: modelContext, appState: appState, isSilent: true)
        }
    }
    
    // Complete entire dish group
    private func completeDish(group: DishGroupedOrder) {
        for order in group.orders {
            order.isFulfilled = true
            order.updatedAt = Date()
            SyncEngine.shared.push(order, appState: appState)
        }
    }
    
    // Complete single person's dish request
    private func completeSingleOrder(order: MealOrder) {
        order.isFulfilled = true
        order.updatedAt = Date()
        SyncEngine.shared.push(order, appState: appState)
    }
    
    // Revert entire dish group
    private func revertDish(group: DishGroupedOrder) {
        for order in group.orders {
            order.isFulfilled = false
            order.updatedAt = Date()
            SyncEngine.shared.push(order, appState: appState)
        }
    }
    
    // Revert single person's dish request
    private func revertSingleOrder(order: MealOrder) {
        order.isFulfilled = false
        order.updatedAt = Date()
        SyncEngine.shared.push(order, appState: appState)
    }
    
    // Complete all past pending orders
    private func completeAllPastOrders() {
        for order in pastPendingOrders {
            order.isFulfilled = true
            order.updatedAt = Date()
            SyncEngine.shared.push(order, appState: appState)
        }
    }
    
    private func formattedOrderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

// Grouped helper struct
struct DishGroupedOrder: Identifiable {
    var id: UUID { dish.id }
    let dish: Dish
    var orders: [MealOrder]
}
