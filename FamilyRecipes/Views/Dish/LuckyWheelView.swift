import SwiftUI

struct LuckyWheelView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    // States
    @State private var rotationAngle: Double = 0.0
    @State private var isSpinning = false
    @State private var selectedDish: Dish?
    @State private var showResultModal = false
    @State private var isOrdering = false
    @State private var orderStatusMessage = ""
    
    // Colors for sectors
    let sectorColors: [Color] = [
        Color(hex: "#FF7654"), // Soft Coral
        Color(hex: "#FFA756"), // Soft Orange
        Color(hex: "#FFCD56"), // Soft Yellow
        Color(hex: "#4BC0C0"), // Teal
        Color(hex: "#36A2EB"), // Blue
        Color(hex: "#9966FF"), // Purple
        Color(hex: "#FF6384"), // Pink
        Color(hex: "#8BC34A")  // Light Green
    ]
    
    // Dynamically prepared items for the wheel (at least 6, max 8)
    var wheelItems: [Dish] {
        let savedDishes = appState.dishes
        if savedDishes.count >= 3 {
            let favorites = savedDishes.filter { $0.isFavorite }
            if favorites.count >= 3 {
                return Array(favorites.prefix(8))
            } else {
                return Array(savedDishes.prefix(8))
            }
        } else {
            // Mock items to pad
            var items = savedDishes
            let mocks = [
                Dish(name: "红烧肉", category: "荤菜", tags: ["经典"], emoji: "🥩", dishDescription: "香气扑鼻，入口即化", ingredients: [], cookNote: ""),
                Dish(name: "清蒸鲈鱼", category: "荤菜", tags: ["清淡"], emoji: "🐟", dishDescription: "鲜嫩滑溜，原汁原味", ingredients: [], cookNote: ""),
                Dish(name: "番茄炒蛋", category: "素菜", tags: ["快手"], emoji: "🍅", dishDescription: "酸甜爽口，拌饭神器", ingredients: [], cookNote: ""),
                Dish(name: "清炒时蔬", category: "素菜", tags: ["健康"], emoji: "🥬", dishDescription: "爽脆清凉，少油健康", ingredients: [], cookNote: ""),
                Dish(name: "麻婆豆腐", category: "素菜", tags: ["川味"], emoji: "🌶️", dishDescription: "麻辣鲜香，十分下饭", ingredients: [], cookNote: ""),
                Dish(name: "酸辣土豆丝", category: "素菜", tags: ["经典"], emoji: "🥔", dishDescription: "酸辣爽脆，百吃不厌", ingredients: [], cookNote: "")
            ]
            for mock in mocks {
                if items.count >= 6 { break }
                if !items.contains(where: { $0.name == mock.name }) {
                    items.append(mock)
                }
            }
            return items
        }
    }
    
    var body: some View {
        ZStack {
            // Theme Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header handles
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                
                // Header Titles
                VStack(spacing: 6) {
                    Text("🎡 今晚吃什么？")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.black)
                        .foregroundColor(Color(hex: "#FF5E36"))
                    
                    Text("纠结点什么？转盘帮你做决定！")
                        .font(.subheadline)
                        .foregroundColor(Color(.secondaryLabel))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                        Text("摇晃手机也可以转动哦")
                    }
                    .font(.caption)
                    .foregroundColor(Color(.tertiaryLabel))
                    .padding(.top, 2)
                }
                
                Spacer()
                
                // Wheel Container
                ZStack {
                    // Outer border ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#FF8F50"), Color(hex: "#FF5E36")],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 8
                        )
                        .frame(width: 304, height: 304)
                        .shadow(color: Color(hex: "#FF5E36").opacity(0.15), radius: 12, x: 0, y: 6)
                    
                    // The Rotating Wheel
                    ZStack {
                        let items = wheelItems
                        let itemCount = items.count
                        let sectorSize = 360.0 / Double(itemCount)
                        
                        // Draw Sectors
                        ForEach(0..<itemCount, id: \.self) { i in
                            let startAngle = Double(i) * sectorSize
                            SectorShape(startAngle: .degrees(startAngle), endAngle: .degrees(startAngle + sectorSize))
                                .fill(sectorColors[i % sectorColors.count])
                            
                            // Sector text and emoji positioned radially
                            let midAngle = startAngle + sectorSize / 2.0
                            HStack {
                                Spacer()
                                VStack(spacing: 4) {
                                    Text(items[i].emoji)
                                        .font(.system(size: 24))
                                    Text(items[i].name)
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                }
                                .frame(width: 90)
                                .rotationEffect(.degrees(-90))
                                .padding(.trailing, 22)
                            }
                            .frame(width: 290, height: 290)
                            .rotationEffect(.degrees(midAngle))
                        }
                    }
                    .rotationEffect(.degrees(rotationAngle))
                    .frame(width: 290, height: 290)
                    .clipShape(Circle())
                    
                    // Wheel Center Button overlay
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                    
                    Button {
                        spin()
                    } label: {
                        Text(isSpinning ? "🎉" : "开始")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.black)
                            .foregroundColor(Color(hex: "#FF5E36"))
                            .frame(width: 66, height: 66)
                            .background(Circle().fill(Color.white))
                    }
                    .disabled(isSpinning)
                }
                .frame(width: 320, height: 320)
                .overlay(
                    // Top Pointer pointing downwards into the wheel
                    Image(systemName: "triangle.fill")
                        .font(.title2)
                        .foregroundColor(Color(hex: "#FF5E36"))
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                        .rotationEffect(.degrees(180))
                        .offset(y: -154),
                    alignment: .center
                )
                
                Spacer()
                
                // Footer Tips / Cancel
                Button("返回点餐") {
                    dismiss()
                }
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#FF5E36"))
                .padding(.bottom, 24)
            }
            .blur(radius: showResultModal ? 4 : 0)
            
            // Premium Overlay Result Card
            if showResultModal, let dish = selectedDish {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            showResultModal = false
                        }
                    }
                
                // Glassmorphism Pop Card
                VStack(spacing: 20) {
                    Text("🎉 选中美味啦！")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(Color(hex: "#FF5E36"))
                        .padding(.top, 10)
                    
                    VStack(spacing: 12) {
                        Text(dish.emoji)
                            .font(.system(size: 64))
                            .bounceAnimation()
                        
                        Text(dish.name)
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.black)
                            .foregroundColor(Color(.label))
                        
                        if !dish.dishDescription.isEmpty {
                            Text(dish.dishDescription)
                                .font(.caption)
                                .foregroundColor(Color(.secondaryLabel))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        
                        Text(dish.category)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(hex: "#FF5E36")))
                    }
                    .padding(.vertical, 8)
                    
                    if !orderStatusMessage.isEmpty {
                        Text(orderStatusMessage)
                            .font(.caption)
                            .foregroundColor(orderStatusMessage.contains("失败") ? .red : .green)
                    }
                    
                    // Buttons
                    VStack(spacing: 10) {
                        Button {
                            confirmOrder(for: dish)
                        } label: {
                            HStack {
                                if isOrdering {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 6)
                                }
                                Text("就是它了！立刻点单")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "#FF8F50"), Color(hex: "#FF5E36")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                            .shadow(color: Color(hex: "#FF5E36").opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .disabled(isOrdering)
                        
                        Button {
                            withAnimation(.spring()) {
                                showResultModal = false
                                spin()
                            }
                        } label: {
                            Text("手气不行，再转一次")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "#FF5E36"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().stroke(Color(hex: "#FF5E36"), lineWidth: 1.5))
                        }
                        .disabled(isOrdering)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(24)
                .frame(width: 300)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onShake {
            spin()
        }
    }
    
    // Core spin logic
    private func spin() {
        guard !isSpinning && !showResultModal else { return }
        isSpinning = true
        orderStatusMessage = ""
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let items = wheelItems
        let itemCount = items.count
        let randomIndex = Int.random(in: 0..<itemCount)
        let sectorSize = 360.0 / Double(itemCount)
        
        // We want the random item to land on the 12 o'clock pointer (270 degrees)
        // rotationAngle needs to rotate such that target index is at 270 degrees.
        // angle = 270 - (mid angle of sector index)
        let targetOffset = 270.0 - (Double(randomIndex) * sectorSize + sectorSize / 2.0)
        
        // 5 complete rotations
        let extraSpins = 360.0 * 5.0
        let currentNormalized = rotationAngle.truncatingRemainder(dividingBy: 360.0)
        let newAngle = rotationAngle - currentNormalized + extraSpins + targetOffset
        
        withAnimation(.spring(response: 4.0, dampingFraction: 0.82, blendDuration: 0)) {
            rotationAngle = newAngle
        }
        
        // Wait for animation to finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            isSpinning = false
            selectedDish = items[randomIndex]
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showResultModal = true
            }
            
            // Soft haptic tick
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    // Create Supabase order directly
    private func confirmOrder(for dish: Dish) {
        guard let member = appState.currentMember else {
            orderStatusMessage = "请先选择您的家庭成员角色！"
            return
        }
        
        isOrdering = true
        orderStatusMessage = ""
        
        let newOrder = MealOrder(
            id: UUID(),
            member: member,
            dish: dish,
            note: "",
            orderDate: Date()
        )
        
        Task {
            do {
                // If this is a mock dish not yet in the cloud database, insert it first
                if !appState.dishes.contains(where: { $0.id == dish.id }) {
                    try await SupabaseManager.shared.upsertDish(dish, url: appState.supabaseURL, key: appState.supabaseKey)
                    await MainActor.run {
                        appState.dishes.append(dish)
                        appState.dishes.sort(by: { $0.name < $1.name })
                    }
                }
                
                try await SupabaseManager.shared.upsertOrder(newOrder, url: appState.supabaseURL, key: appState.supabaseKey)
                await MainActor.run {
                    appState.orders.insert(newOrder, at: 0) // Sync locally
                    isOrdering = false
                    orderStatusMessage = "点单成功！🎉"
                    // Dismiss view after 1 second so they can see confirmation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isOrdering = false
                    orderStatusMessage = "点单失败：\(error.localizedDescription)"
                }
            }
        }
    }
}

// Custom Sector shape for rendering the slices of the wheel
struct SectorShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        
        return path
    }
}

// Interactive bounce view modifier helper
struct BounceViewModifier: ViewModifier {
    @State private var scale: CGFloat = 0.5
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    scale = 1.0
                }
            }
    }
}

extension View {
    func bounceAnimation() -> some View {
        self.modifier(BounceViewModifier())
    }
}
