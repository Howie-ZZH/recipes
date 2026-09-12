import SwiftUI
import SwiftData

struct WheelSliceItem: Identifiable {
    let id = UUID()
    let dish: Dish
    let image: UIImage?
    let name: String
    let emoji: String
}

struct LuckyWheelView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allDishes: [Dish]
    @Query private var members: [FamilyMember]
    
    // States
    @State private var rotationAngle: Double = 0.0
    @State private var isSpinning = false
    @State private var selectedDish: Dish?
    @State private var showResultModal = false
    @State private var isOrdering = false
    @State private var orderStatusMessage = ""
    @State private var pointerWiggle = false
    @State private var cachedSlices: [WheelSliceItem] = []
    
    // Haptic feedback generators pre-instantiated
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
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
    
    // Dynamically prepared items for the wheel (real dishes directly from database)
    private func updateCachedSlices() {
        let savedDishes = allDishes
        var rawDishes: [Dish] = []
        if !savedDishes.isEmpty {
            if savedDishes.count >= 4 {
                rawDishes = Array(savedDishes.prefix(12))
            } else {
                while rawDishes.count < 6 {
                    rawDishes.append(contentsOf: savedDishes)
                }
                rawDishes = Array(rawDishes.prefix(6))
            }
        } else {
            rawDishes = SampleData.mockDishes
        }
        
        // Pre-decode all UIImages in memory once to prevent frame-rate drops during rotation
        cachedSlices = rawDishes.map { dish in
            let img: UIImage? = dish.imageData.flatMap { UIImage(data: $0) }
            return WheelSliceItem(dish: dish, image: img, name: dish.name, emoji: dish.emoji)
        }
    }
    
    var body: some View {
        ZStack {
            // Theme Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header handles & Top Right Exit Button
                ZStack {
                    Capsule()
                        .fill(Color(.systemGray4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)
                    
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 12)
                    }
                }
                
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
                    
                    // The Rotating Wheel (GPU Accelerated & Cached Textures)
                    ZStack {
                        let items = cachedSlices
                        let itemCount = max(items.count, 1)
                        let sectorSize = 360.0 / Double(itemCount)
                        
                        // Draw Sectors
                        ForEach(0..<items.count, id: \.self) { i in
                            let item = items[i]
                            let startAngle = Double(i) * sectorSize
                            SectorShape(startAngle: .degrees(startAngle), endAngle: .degrees(startAngle + sectorSize))
                                .fill(sectorColors[i % sectorColors.count])
                            
                            // Sector text and pre-decoded image/emoji positioned radially
                            let midAngle = startAngle + sectorSize / 2.0
                            HStack {
                                Spacer()
                                VStack(spacing: 4) {
                                    if let uiImage = item.image {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 26, height: 26)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                                    } else {
                                        Text(item.emoji.isEmpty ? "🍲" : item.emoji)
                                            .font(.system(size: 24))
                                    }
                                    
                                    Text(item.name)
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
                    .buttonStyle(ScaledButtonStyle())
                    .disabled(isSpinning)
                }
                .frame(width: 320, height: 320)
                .overlay(
                    // Top Pointer pointing downwards into the wheel with smooth continuous animation
                    Image(systemName: "triangle.fill")
                        .font(.title2)
                        .foregroundColor(Color(hex: "#FF5E36"))
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                        .rotationEffect(.degrees(180 + (pointerWiggle ? -10 : 10)))
                        .animation(pointerWiggle ? .easeInOut(duration: 0.09).repeatForever(autoreverses: true) : .easeOut(duration: 0.2), value: pointerWiggle)
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
                Color.black.opacity(0.35)
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
                        // Real Dish Image or Emoji Fallback
                        Group {
                            if let data = dish.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Text(dish.emoji.isEmpty ? "🍲" : dish.emoji)
                                    .font(.system(size: 56))
                            }
                        }
                        .frame(width: 90, height: 90)
                        .background(
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#FFF4E8"), Color(hex: "#FFEBE7")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        )
                        .clipped()
                        .cornerRadius(45)
                        .shadow(color: Color(hex: "#FF5E36").opacity(0.2), radius: 8, x: 0, y: 4)
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
                        .buttonStyle(ScaledButtonStyle())
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
                        .buttonStyle(ScaledButtonStyle())
                        .disabled(isOrdering)
                        
                        Button {
                            showResultModal = false
                            dismiss()
                        } label: {
                            Text("退出转盘")
                                .font(.subheadline)
                                .foregroundColor(Color(.secondaryLabel))
                                .padding(.top, 2)
                        }
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
                .overlay(
                    Button {
                        withAnimation(.spring()) {
                            showResultModal = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(.tertiaryLabel))
                            .padding(14)
                    },
                    alignment: .topTrailing
                )
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onShake {
            spin()
        }
        .onAppear {
            updateCachedSlices()
            impactLight.prepare()
            impactMedium.prepare()
        }
        .onChange(of: allDishes) { _, _ in
            updateCachedSlices()
        }
        .task {
            await SyncEngine.shared.syncDown(context: modelContext, appState: appState)
            updateCachedSlices()
        }
    }
    
    // Core spin logic (Ultra-smooth 60/120fps animation)
    private func spin() {
        if cachedSlices.isEmpty {
            updateCachedSlices()
        }
        guard !isSpinning && !showResultModal && !cachedSlices.isEmpty else { return }
        isSpinning = true
        orderStatusMessage = ""
        pointerWiggle = true
        
        // Initial tactile impulse
        impactMedium.impactOccurred()
        
        // Decelerating tactile feedback (lightweight, background-timed)
        let tickCount = 18
        for i in 0..<tickCount {
            let progress = Double(i) / Double(tickCount)
            let delay = pow(progress, 2.2) * 3.8
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay) {
                if self.isSpinning {
                    DispatchQueue.main.async {
                        self.impactLight.impactOccurred()
                    }
                }
            }
        }
        
        let items = cachedSlices
        let itemCount = items.count
        let randomIndex = Int.random(in: 0..<itemCount)
        let sectorSize = 360.0 / Double(itemCount)
        
        // Calculate exact landing angle for target item at 12 o'clock pointer (270 deg)
        let targetOffset = 270.0 - (Double(randomIndex) * sectorSize + sectorSize / 2.0)
        let extraSpins = 360.0 * 5.0
        let currentNormalized = rotationAngle.truncatingRemainder(dividingBy: 360.0)
        let newAngle = rotationAngle - currentNormalized + extraSpins + targetOffset
        
        // Pure single SwiftUI Spring animation for the entire rotation
        withAnimation(.spring(response: 3.8, dampingFraction: 0.82, blendDuration: 0)) {
            rotationAngle = newAngle
        }
        
        // Spin completion handler
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.85) {
            isSpinning = false
            pointerWiggle = false
            selectedDish = items[randomIndex].dish
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showResultModal = true
            }
            
            notificationFeedback.notificationOccurred(.success)
        }
    }
    
    // Create Supabase order directly
    private func confirmOrder(for dish: Dish) {
        guard let activeMemberId = appState.activeMemberId,
              let member = members.first(where: { $0.id == activeMemberId }) else {
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
        
        // If this is a mock dish not yet in the cloud database, insert it first
        if !allDishes.contains(where: { $0.id == dish.id }) {
            modelContext.insert(dish)
            SyncEngine.shared.push(dish, appState: appState)
        }
        
        modelContext.insert(newOrder)
        SyncEngine.shared.push(newOrder, appState: appState)
        
        isOrdering = false
        orderStatusMessage = "点单成功！🎉"
        // Dismiss view after 1 second so they can see confirmation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
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
