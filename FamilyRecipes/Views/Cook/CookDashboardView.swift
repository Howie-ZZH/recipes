import SwiftUI

struct CookDashboardView: View {
    @Environment(AppState.self) private var appState
    
    @State private var dashboardMode = 0 // 0: 今日菜品, 1: 智能买菜清单
    @State private var checkedIngredients: Set<String> = []
    
    // Active today orders from AppState memory
    var activeOrders: [MealOrder] {
        let calendar = Calendar.current
        return appState.orders.filter { order in
            calendar.isDateInToday(order.orderDate) && !order.isFulfilled
        }
    }
    
    // Group active orders by dish
    var groupedOrders: [DishGroupedOrder] {
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
            Picker("工作台模式", selection: $dashboardMode) {
                Text("🍳 今日菜单 (\(activeOrders.count))").tag(0)
                Text("🛒 自动买菜单 (\(shoppingList.count))").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            
            if dashboardMode == 0 {
                // TODAY'S DISH PREPARATION WORKSPACE
                if groupedOrders.isEmpty {
                    VStack(spacing: 24) {
                        Spacer()
                        Text("🧑‍🍳")
                            .font(.system(size: 64))
                        Text("今天还没有人点餐，或者点餐已全部做好啦！")
                            .font(.subheadline)
                            .foregroundColor(Color(.secondaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(groupedOrders) { group in
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text(group.dish.emoji)
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.dish.name)
                                            .font(.headline)
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
                                        Text("已做好")
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
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(Color(.systemGray4))
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
                        
                        List {
                            ForEach(shoppingList, id: \.self) { ingredient in
                                Button {
                                    withAnimation(.interactiveSpring()) {
                                        if checkedIngredients.contains(ingredient) {
                                            checkedIngredients.remove(ingredient)
                                        } else {
                                            checkedIngredients.insert(ingredient)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: checkedIngredients.contains(ingredient) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundColor(checkedIngredients.contains(ingredient) ? .green : Color(hex: "#FF5E36"))
                                        
                                        Text(ingredient)
                                            .font(.system(.body, design: .rounded))
                                            .foregroundColor(checkedIngredients.contains(ingredient) ? Color(.tertiaryLabel) : Color(.label))
                                            .strikethrough(checkedIngredients.contains(ingredient), color: Color(.tertiaryLabel))
                                        
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color(.secondarySystemGroupedBackground))
                            }
                        }
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                        .listStyle(.insetGrouped)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // Complete entire dish group
    private func completeDish(group: DishGroupedOrder) {
        withAnimation(.easeInOut(duration: 0.3)) {
            for order in group.orders {
                Task {
                    await appState.fulfillOrder(order)
                }
            }
        }
    }
    
    // Complete single person's dish request
    private func completeSingleOrder(order: MealOrder) {
        withAnimation(.easeInOut(duration: 0.25)) {
            Task {
                await appState.fulfillOrder(order)
            }
        }
    }
}

// Grouped helper struct
struct DishGroupedOrder: Identifiable {
    var id: UUID { dish.id }
    let dish: Dish
    var orders: [MealOrder]
}
