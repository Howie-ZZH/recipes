import SwiftUI
import PhotosUI

struct DishDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @Bindable var dish: Dish
    
    @State private var showingEditSheet = false
    @State private var orderNote = ""
    @State private var showingOrderSuccess = false
    @State private var isImageViewerPresented = false
    @State private var isOrdering = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Large Food Header card
                    VStack(spacing: 16) {
                        Group {
                            if let data = dish.imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .onTapGesture {
                                        isImageViewerPresented = true
                                    }
                            } else {
                                Text(dish.emoji)
                                    .font(.system(size: 76))
                            }
                        }
                        .frame(width: 120, height: 120)
                        .background(
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#FFF4E8"), Color(hex: "#FFEBE7")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        )
                        .clipped()
                        .cornerRadius(60)
                        .shadow(color: Color(hex: "#FF5E36").opacity(0.12), radius: 12, x: 0, y: 8)
                        .padding(.top, 20)
                        
                        Text(dish.name)
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.black)
                        
                        HStack(spacing: 10) {
                            Text(dish.category)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color(hex: "#FF5E36")))
                            
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                    dish.isFavorite.toggle()
                                    Task {
                                        await appState.updateDish(dish)
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: dish.isFavorite ? "heart.fill" : "heart")
                                    Text(dish.isFavorite ? "最爱" : "收藏")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(dish.isFavorite ? .red : Color(.secondaryLabel))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .strokeBorder(dish.isFavorite ? Color.red : Color(.separator), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Description
                    if !dish.dishDescription.isEmpty {
                        Text(dish.dishDescription)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(Color(.secondaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                    
                    // Tags Row
                    if !dish.tags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(dish.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "#FF5E36"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color(hex: "#FF5E36").opacity(0.08)))
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Divider()
                        .padding(.horizontal, 24)
                    
                    // Quick Order Section for Active Member
                    if let activeMember = appState.currentMember {
                        VStack(spacing: 14) {
                            HStack {
                                Image(systemName: "pencil.line")
                                    .foregroundColor(Color(hex: "#FF5E36"))
                                TextField("有啥特殊想对掌勺人说的？(如：不要辣、少盐)", text: $orderNote)
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal, 24)
                            
                            Button {
                                createOrder(member: activeMember)
                            } label: {
                                HStack(spacing: 8) {
                                    if isOrdering {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "plus.circle.fill")
                                        Text("今天就吃这道菜！")
                                    }
                                }
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#FF5E36"), Color(hex: "#FF9F5A")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color(hex: "#FF5E36").opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(ScaledButtonStyle())
                            .padding(.horizontal, 24)
                            .disabled(isOrdering)
                        }
                    }
                    
                    // Ingredients List Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "basket.fill")
                                .foregroundColor(Color(hex: "#FF5E36"))
                            Text("食材清单")
                                .font(.headline)
                            Spacer()
                        }
                        
                        if dish.ingredients.isEmpty {
                            Text("无需特殊配料或未记录食材。")
                                .font(.subheadline)
                                .foregroundColor(Color(.secondaryLabel))
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(dish.ingredients, id: \.self) { ingredient in
                                    HStack(spacing: 10) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 6))
                                            .foregroundColor(Color(hex: "#FF5E36"))
                                        
                                        Text(ingredient)
                                            .font(.subheadline)
                                            .foregroundColor(Color(.label))
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .padding(.horizontal, 24)
                    
                    // Cook notes
                    if !dish.cookNote.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text("掌勺人秘籍")
                                    .font(.headline)
                                Spacer()
                            }
                            
                            Text(dish.cookNote)
                                .font(.subheadline)
                                .foregroundColor(Color(.secondaryLabel))
                                .lineSpacing(4)
                        }
                        .padding(20)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("菜品详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FF5E36"))
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("编辑") {
                        showingEditSheet = true
                    }
                    .foregroundColor(Color(hex: "#FF5E36"))
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditDishSheet(dish: dish)
                    .environment(appState)
            }
            .fullScreenCover(isPresented: $isImageViewerPresented) {
                FullScreenImageViewer(imageData: dish.imageData)
            }
            .overlay {
                if showingOrderSuccess {
                    OrderSuccessOverlay()
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
    
    private func createOrder(member: FamilyMember) {
        isOrdering = true
        Task {
            await appState.createOrder(member: member, dish: dish, note: orderNote)
            isOrdering = false
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                showingOrderSuccess = true
            }
            
            // Hide overlay after 1.6 seconds and close details
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                showingOrderSuccess = false
                dismiss()
            }
        }
    }
}

// Order Success View Modal Overlay
struct OrderSuccessOverlay: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("🎉")
                .font(.system(size: 64))
            Text("点餐成功！")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("已将您的需求发送给掌勺人。")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 24)
        .background(
            Color.black.opacity(0.8)
                .background(.ultraThinMaterial)
        )
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 10)
    }
}

// Edit Dish Sheet
struct EditDishSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var dish: Dish
    
    @State private var rawIngredients = ""
    @State private var rawTags = ""
    
    // Photo Picker States
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isGeneratingAIImage = false
    @State private var aiError = ""
    @State private var isImageViewerPresented = false
    @State private var isSaving = false
    
    let categories = ["荤菜", "素菜", "汤羹", "主食", "其他"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("修改基本信息") {
                    TextField("菜品名字", text: $dish.name)
                    
                    Picker("分类", selection: $dish.category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section("菜品主图") {
                    HStack(spacing: 16) {
                        if let imageData = dish.imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .cornerRadius(12)
                                .clipped()
                                .onTapGesture {
                                    isImageViewerPresented = true
                                }
                                .overlay(
                                    Button {
                                        withAnimation {
                                            dish.imageData = nil
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
                        
                        VStack(alignment: .leading, spacing: 10) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("从相册上传")
                                }
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "#FF5E36"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color(hex: "#FF5E36").opacity(0.1)))
                            }
                            .buttonStyle(.borderless)
                            .onChange(of: selectedPhotoItem) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                        await MainActor.run {
                                            withAnimation {
                                                dish.imageData = data
                                            }
                                        }
                                    }
                                }
                            }
                            
                            Button {
                                generateAIImage()
                            } label: {
                                HStack {
                                    if isGeneratingAIImage {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "wand.and.stars")
                                    }
                                    Text(isGeneratingAIImage ? "AI 生成中..." : "AI 一键生图")
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(dish.name.isEmpty ? Color.gray : Color(hex: "#FF5E36"))
                                )
                            }
                            .buttonStyle(.borderless)
                            .disabled(dish.name.isEmpty || isGeneratingAIImage)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if !aiError.isEmpty {
                        Text(aiError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Section("详细说明") {
                    TextField("一句话介绍", text: $dish.dishDescription)
                    TextField("标签（用英文或中文逗号分隔）", text: $rawTags)
                        .onAppear {
                            rawTags = dish.tags.joined(separator: ", ")
                        }
                }
                
                Section("食材清单 (每行一个)") {
                    TextEditor(text: $rawIngredients)
                        .frame(height: 100)
                        .onAppear {
                            rawIngredients = dish.ingredients.joined(separator: "\n")
                        }
                }
                
                Section("烹饪贴士") {
                    TextEditor(text: $dish.cookNote)
                        .frame(height: 80)
                }
            }
            .navigationTitle("编辑菜品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        // Process lists
                        dish.ingredients = rawIngredients
                            .components(separatedBy: .newlines)
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        
                        dish.tags = rawTags
                            .components(separatedBy: CharacterSet(charactersIn: ",，"))
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        
                        isSaving = true
                        Task {
                            await appState.updateDish(dish)
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("完成")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(Color(hex: "#FF5E36"))
                    .disabled(isSaving)
                }
            }
            .fullScreenCover(isPresented: $isImageViewerPresented) {
                FullScreenImageViewer(imageData: dish.imageData)
            }
        }
    }
    
    private func generateAIImage() {
        guard !dish.name.isEmpty else { return }
        isGeneratingAIImage = true
        aiError = ""
        
        Task {
            do {
                let data = try await AIEngine.generateAIImage(for: dish.name)
                await MainActor.run {
                    withAnimation {
                        dish.imageData = data
                        self.isGeneratingAIImage = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.aiError = "AI 生图失败，请稍后重试。"
                    self.isGeneratingAIImage = false
                }
            }
        }
    }
}

// Helper: Custom Flow Layout for pill badges
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let width: CGFloat = proposal.width ?? 320
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeightInRow: CGFloat = 0
        
        for size in sizes {
            if currentX + size.width > width {
                // New Line
                currentX = 0
                currentY += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            
            currentX += size.width + spacing
            maxHeightInRow = max(maxHeightInRow, size.height)
        }
        
        height = currentY + maxHeightInRow
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxHeightInRow: CGFloat = 0
        let spacingX = spacing
        let spacingY = spacing
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += maxHeightInRow + spacingY
                maxHeightInRow = 0
            }
            
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacingX
            maxHeightInRow = max(maxHeightInRow, size.height)
        }
    }
}
