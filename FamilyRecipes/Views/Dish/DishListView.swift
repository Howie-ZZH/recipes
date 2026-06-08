import SwiftUI
import PhotosUI

struct DishListView: View {
    @Environment(AppState.self) private var appState
    
    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    @State private var showingAddSheet = false
    @State private var selectedDish: Dish?
    
    let categories = ["全部", "荤菜", "素菜", "汤羹", "主食", "其他"]
    
    var filteredDishes: [Dish] {
        appState.dishes.filter { dish in
            let matchesSearch = searchText.isEmpty || 
                                dish.name.localizedCaseInsensitiveContains(searchText) ||
                                dish.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) ||
                                dish.ingredients.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            
            let matchesCategory = selectedCategory == "全部" || dish.category == selectedCategory
            
            return matchesSearch && matchesCategory
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar & Add Button
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(.secondaryLabel))
                    TextField("搜索菜名、食材或标签...", text: $searchText)
                        .font(.subheadline)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "#FF5E36"))
                }
                .buttonStyle(ScaledButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            // Category Horizontal Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                selectedCategory = category
                            }
                        } label: {
                            Text(category)
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedCategory == category ? Color(hex: "#FF5E36") : Color(.systemGroupedBackground))
                                )
                                .foregroundColor(selectedCategory == category ? .white : Color(.secondaryLabel))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            
            // Error Banner
            if !appState.networkError.isEmpty {
                Text(appState.networkError)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            
            // Recipe List
            if filteredDishes.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Text("🍲")
                        .font(.system(size: 64))
                    Text("家里的菜谱还是空的，或者换个搜索词试试？")
                        .font(.subheadline)
                        .foregroundColor(Color(.secondaryLabel))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredDishes) { dish in
                        DishRow(dish: dish)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDish = dish
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteDishes)
                }
                .listStyle(.plain)
                .refreshable {
                    // Pull to refresh from Supabase
                    await appState.fetchAllData()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingAddSheet) {
            AddDishSheet()
                .environment(appState)
        }
        .sheet(item: $selectedDish) { dish in
            DishDetailView(dish: dish)
                .environment(appState)
        }
    }
    
    private func deleteDishes(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let dish = filteredDishes[index]
                let dishId = dish.id
                Task {
                    await appState.deleteDish(id: dishId)
                }
            }
        }
    }
}

// Custom Dish Row Card
struct DishRow: View {
    let dish: Dish
    
    var body: some View {
        HStack(spacing: 16) {
            // Food Image or Emoji Badge
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
            .frame(width: 68, height: 68)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#FFEBE7"), Color(hex: "#FFF4E8")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipped()
            .cornerRadius(18)
            .shadow(color: Color(hex: "#FF5E36").opacity(0.08), radius: 5, x: 0, y: 3)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(dish.name)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                    
                    if dish.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Text(dish.category)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "#FF5E36"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(hex: "#FF5E36").opacity(0.1)))
                }
                
                if !dish.dishDescription.isEmpty {
                    Text(dish.dishDescription)
                        .font(.caption)
                        .foregroundColor(Color(.secondaryLabel))
                        .lineLimit(1)
                }
                
                // Tags
                if !dish.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(dish.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.025), radius: 8, x: 0, y: 4)
    }
}

// Add Dish Sheet
struct AddDishSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var category = "荤菜"
    @State private var emoji = "🍳"
    @State private var dishDescription = ""
    @State private var rawIngredients = ""
    @State private var cookNote = ""
    @State private var rawTags = ""
    
    // Photo Picker States
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isGeneratingAIImage = false
    @State private var aiError = ""
    @State private var isImageViewerPresented = false
    @State private var isSaving = false
    
    let categories = ["荤菜", "素菜", "汤羹", "主食", "其他"]
    let foodEmojis = ["🍳", "🍲", "🥩", "🐟", "🥔", "🥣", "🍚", "🥟", "🍤", "🍗", "🥬", "🌽", "🍖", "🍜", "🍞", "🍓"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本内容") {
                    TextField("菜品名字 (如: 番茄炒蛋)", text: $name)
                    
                    Picker("分类", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section("菜品主图 (选填)") {
                    HStack(spacing: 16) {
                        if let imageData = imageData, let uiImage = UIImage(data: imageData) {
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
                                                self.imageData = data
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
                                        .fill(name.isEmpty ? Color.gray : Color(hex: "#FF5E36"))
                                )
                            }
                            .buttonStyle(.borderless)
                            .disabled(name.isEmpty || isGeneratingAIImage)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    
                    if !aiError.isEmpty {
                        Text(aiError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Section("图标 Emoji (未上传主图时默认展示)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(foodEmojis, id: \.self) { food in
                                Text(food)
                                    .font(.system(size: 34))
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(emoji == food ? Color(hex: "#FF5E36").opacity(0.18) : Color.clear)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(emoji == food ? Color(hex: "#FF5E36") : Color.clear, lineWidth: 2)
                                    )
                                    .onTapGesture {
                                        withAnimation(.interactiveSpring()) {
                                            emoji = food
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                
                Section("菜品详情与标签") {
                    TextField("一句话介绍（如：酸甜爽口）", text: $dishDescription)
                    TextField("标签（英文或中文逗号分隔，如：微辣, 清淡）", text: $rawTags)
                }
                
                Section("食材清单 (每行一个，生成买菜清单使用)") {
                    TextEditor(text: $rawIngredients)
                        .frame(height: 100)
                        .overlay(
                            Group {
                                if rawIngredients.isEmpty {
                                    Text("例如：\n五花肉 500g\n大葱 1根\n生姜 3片")
                                        .foregroundColor(Color(.placeholderText))
                                        .font(.subheadline)
                                        .padding(.leading, 4)
                                        .padding(.top, 8)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                Section("烹饪小贴士") {
                    TextEditor(text: $cookNote)
                        .frame(height: 80)
                }
            }
            .navigationTitle("添加新菜品")
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
                        let ingredientsList = rawIngredients
                            .components(separatedBy: .newlines)
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        
                        let tagsList = rawTags
                            .components(separatedBy: CharacterSet(charactersIn: ",，"))
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        
                        let newDish = Dish(
                            name: name.isEmpty ? "美味新菜" : name,
                            category: category,
                            tags: tagsList,
                            emoji: emoji,
                            dishDescription: dishDescription,
                            ingredients: ingredientsList,
                            cookNote: cookNote,
                            imageData: imageData
                        )
                        isSaving = true
                        Task {
                            do {
                                try await appState.addDish(newDish)
                                await MainActor.run {
                                    isSaving = false
                                    dismiss()
                                }
                            } catch {
                                await MainActor.run {
                                    isSaving = false
                                    self.aiError = "无法添加菜品：\(error.localizedDescription)"
                                }
                            }
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(Color(hex: "#FF5E36"))
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .fullScreenCover(isPresented: $isImageViewerPresented) {
                FullScreenImageViewer(imageData: imageData)
            }
        }
    }
    
    private func generateAIImage() {
        guard !name.isEmpty else { return }
        isGeneratingAIImage = true
        aiError = ""
        
        Task {
            do {
                let data = try await AIEngine.generateAIImage(for: name)
                await MainActor.run {
                    withAnimation {
                        self.imageData = data
                        self.isGeneratingAIImage = false
                    }
                }
            } catch {
                print("AI Image Generation Error: \(error)")
                await MainActor.run {
                    self.aiError = "AI 生图失败，请稍后重试。原因: \(error.localizedDescription)"
                    self.isGeneratingAIImage = false
                }
            }
        }
    }
}
