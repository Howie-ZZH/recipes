import SwiftUI

struct OrderView: View {
    @Environment(AppState.self) private var appState
    
    @State private var selectedDish: Dish?
    @State private var showingLuckyWheel = false
    
    // Filter orders to today only from AppState memory
    var todayOrders: [MealOrder] {
        let calendar = Calendar.current
        return appState.orders.filter { order in
            calendar.isDateInToday(order.orderDate) && !order.isFulfilled
        }
    }
    
    // Group today's orders by Dish to show duplicate requests concisely
    var groupedTodayOrders: [DishTodayOrder] {
        var groups: [UUID: DishTodayOrder] = [:]
        for order in todayOrders {
            guard let dish = order.dish else { continue }
            if var group = groups[dish.id] {
                group.orders.append(order)
                groups[dish.id] = group
            } else {
                groups[dish.id] = DishTodayOrder(dish: dish, orders: [order])
            }
        }
        return Array(groups.values).sorted { $0.orders.count > $1.orders.count }
    }
    
    var popularDishes: [Dish] {
        let dishes = appState.dishes
        return dishes.filter { $0.isFavorite }.prefix(4).isEmpty ? Array(dishes.prefix(4)) : dishes.filter { $0.isFavorite }
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                
                // Welcome Banner Header Card
                if let member = appState.currentMember {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("你好呀, \(member.name) \(member.emoji)")
                                    .font(.system(.title2, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(hex: "#FF5E36"))
                                
                                Text("想好今天吃什么了吗？")
                                    .font(.subheadline)
                                    .foregroundColor(Color(.secondaryLabel))
                            }
                            Spacer()
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .shadow(color: Color.black.opacity(0.015), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 16)
                }
                
                // 「今天吃什么」大转盘入口卡片 (精致白底卡片 + 渐变图标与右侧小气泡按钮)
                Button {
                    showingLuckyWheel = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#FF5E36").opacity(0.1))
                                .frame(width: 44, height: 44)
                            Text("🎡")
                                .font(.title3)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("今天吃什么？")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(Color(.label))
                            
                            Text("纠结点什么？转盘帮你做决定！")
                                .font(.system(size: 11))
                                .foregroundColor(Color(.secondaryLabel))
                        }
                        
                        Spacer()
                        
                        // Action pill button
                        HStack(spacing: 4) {
                            Text("立即去转")
                                .font(.system(size: 11, weight: .bold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#FF8F50"), Color(hex: "#FF5E36")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                        .shadow(color: Color(hex: "#FF5E36").opacity(0.25), radius: 4, x: 0, y: 2)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.015), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(ScaledButtonStyle())
                .padding(.horizontal, 16)
                
                // 1. Today's Order Panel (家庭今日已点)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("👨‍👩‍👧‍👦 家庭今日点单")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text("\(todayOrders.count) 道已点")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#FF5E36"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(hex: "#FF5E36").opacity(0.1)))
                    }
                    .padding(.horizontal, 16)
                    
                    if groupedTodayOrders.isEmpty {
                        VStack(spacing: 12) {
                            Text("⏳")
                                .font(.system(size: 32))
                            Text("今天还没有人点餐哦\n快去下方“推荐菜品”或“共享菜谱”点一个吧！")
                                .font(.caption)
                                .foregroundColor(Color(.tertiaryLabel))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(groupedTodayOrders) { group in
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text(group.dish.emoji)
                                                .font(.title3)
                                            Text(group.dish.name)
                                                .font(.system(.subheadline, design: .rounded))
                                                .fontWeight(.bold)
                                                .lineLimit(1)
                                        }
                                        
                                        // Avatars of members who ordered this
                                        HStack(spacing: -8) {
                                            ForEach(group.orders.prefix(5)) { order in
                                                Text(order.member?.emoji ?? "👤")
                                                    .font(.footnote)
                                                    .frame(width: 24, height: 24)
                                                    .background(Circle().fill(Color.orange.opacity(0.2)))
                                                    .overlay(Circle().stroke(Color(.secondarySystemGroupedBackground), lineWidth: 1.5))
                                            }
                                            
                                            if group.orders.count > 5 {
                                                Text("+\(group.orders.count - 5)")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .frame(width: 24, height: 24)
                                                    .background(Circle().fill(Color(.separator)))
                                                    .foregroundColor(Color(.secondaryLabel))
                                                    .overlay(Circle().stroke(Color(.secondarySystemGroupedBackground), lineWidth: 1.5))
                                            }
                                        }
                                    }
                                    .padding(14)
                                    .frame(width: 150)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(18)
                                    .shadow(color: Color.black.opacity(0.015), radius: 6, x: 0, y: 3)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                
                // 2. Favorite / Recommended Dishes (为你推荐)
                VStack(alignment: .leading, spacing: 14) {
                    Text("⭐️ 大家爱吃 / 推荐菜品")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                    
                    if appState.dishes.isEmpty {
                        Text("暂无推荐，先去“共享菜谱”添加一些常吃菜吧！")
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                            .padding(.horizontal, 16)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(popularDishes) { dish in
                                Button {
                                    selectedDish = dish
                                } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Group {
                                            if let data = dish.imageData, let uiImage = UIImage(data: data) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                            } else {
                                                Text(dish.emoji)
                                                    .font(.system(size: 40))
                                            }
                                        }
                                        .frame(height: 80)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(LinearGradient(
                                                    colors: [Color(hex: "#FFFBF0"), Color(hex: "#FFEBE7")],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ))
                                        )
                                        .clipped()
                                        .cornerRadius(16)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(dish.name)
                                                .font(.system(.subheadline, design: .rounded))
                                                .fontWeight(.bold)
                                                .foregroundColor(Color(.label))
                                                .lineLimit(1)
                                            
                                            Text(dish.category)
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(Color(hex: "#FF5E36"))
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                    .padding(12)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(20)
                                    .shadow(color: Color.black.opacity(0.01), radius: 5, x: 0, y: 3)
                                }
                                .buttonStyle(ScaledButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                
                // 3. Fast Cook Access Banner
                // 3. Fast Cook Access Callout (精致的iOS提示性卡片，使用轻量橙色背景加左侧高亮竖条线)
                if appState.currentMember?.role == "Cook" {
                    HStack(spacing: 12) {
                        // Left vertical accent bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "#FF5E36"))
                            .frame(width: 4)
                            .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("👩‍🍳 您是今日掌勺人")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "#FF5E36"))
                            
                            Text("大家点完餐后，点击下方“掌勺面板”可汇总订单并查看买菜清单。")
                                .font(.system(size: 11))
                                .foregroundColor(Color(.secondaryLabel))
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "#FF5E36").opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#FF5E36").opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $selectedDish) { dish in
            DishDetailView(dish: dish)
                .environment(appState)
        }
        .sheet(isPresented: $showingLuckyWheel) {
            LuckyWheelView()
                .environment(appState)
        }
        .refreshable {
            await appState.fetchAllData()
        }
    }
}

// Grouped Helper Class
struct DishTodayOrder: Identifiable {
    var id: UUID { dish.id }
    let dish: Dish
    var orders: [MealOrder]
}
