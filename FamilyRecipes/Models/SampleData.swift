import Foundation

struct SampleData {
    static var mockMembers: [FamilyMember] {
        let mom = FamilyMember(name: "妈妈", emoji: "👩‍🍳", role: "Cook")
        let dad = FamilyMember(name: "爸爸", emoji: "👨", role: "Member")
        let kid = FamilyMember(name: "宝贝", emoji: "👧", role: "Member")
        return [mom, dad, kid]
    }
    
    static var mockDishes: [Dish] {
        return [
            Dish(name: "西红柿炒鸡蛋", category: "素菜", tags: ["清淡", "酸甜", "快手"], emoji: "🍳", 
                 dishDescription: "家庭餐桌上的常客，酸甜可口，老少皆宜。", 
                 ingredients: ["西红柿 2个", "鸡蛋 3个", "小葱 2根", "白糖 1勺"], 
                 cookNote: "鸡蛋打散炒至八成熟盛出，西红柿多炒出沙和汁水再倒回鸡蛋。"),
            
            Dish(name: "红烧肉", category: "荤菜", tags: ["咸甜", "下饭", "硬菜"], emoji: "🥩", 
                 dishDescription: "经典本帮红烧肉，色泽红亮，肥而不腻。", 
                 ingredients: ["五花肉 500g", "冰糖 30g", "八角 2个", "生抽 2勺", "老抽 1勺", "黄酒 2勺"], 
                 cookNote: "肉要先焯水，小火慢炖40分钟让油脂溢出，最后大火收汁。"),
            
            Dish(name: "清蒸鲈鱼", category: "荤菜", tags: ["清淡", "高蛋白", "鲜美"], emoji: "🐟", 
                 dishDescription: "保留了鱼肉最本真的鲜味，营养丰富。", 
                 ingredients: ["鲈鱼 1条", "大葱 1根", "生姜 1块", "蒸鱼豉油 2勺", "食用油 20ml"], 
                 cookNote: "水烧大开后再入锅，大火蒸7-8分钟，出锅泼热油激发葱姜香气。"),
            
            Dish(name: "酸辣土豆丝", category: "素菜", tags: ["酸辣", "快手", "爽口"], emoji: "🥔", 
                 dishDescription: "口感脆爽，酸辣开胃的家常小炒。", 
                 ingredients: ["土豆 2个", "干辣椒 3个", "花椒 10粒", "白醋 2勺", "青椒 1个"], 
                 cookNote: "土豆丝切好后用水清洗掉淀粉，大火快炒。"),
            
            Dish(name: "番茄牛腩煲", category: "荤菜", tags: ["酸甜", "浓郁", "下饭"], emoji: "🍲", 
                 dishDescription: "汤汁浓郁，牛腩软烂入味，汤汁拌饭一绝。", 
                 ingredients: ["牛腩 600g", "西红柿 3个", "洋葱 半个", "生姜 1块"], 
                 cookNote: "牛腩先炖至软烂，再加入炒好的浓郁番茄泥慢炖，味道更醇厚。")
        ]
    }
    
    static var mockOrders: [MealOrder] {
        let members = mockMembers
        let dishes = mockDishes
        
        let order1 = MealOrder(member: members[1], dish: dishes[0], note: "少糖多汁")
        let order2 = MealOrder(member: members[2], dish: dishes[0], note: "鸡蛋要嫩")
        let order3 = MealOrder(member: members[1], dish: dishes[1], note: "少吃肥肉")
        let order4 = MealOrder(member: members[0], dish: dishes[2], note: "多放点葱丝")
        
        return [order1, order2, order3, order4]
    }
    
    @MainActor
    static var previewState: AppState {
        let state = AppState()
        state.members = mockMembers
        state.dishes = mockDishes
        state.orders = mockOrders
        state.setActiveMember(mockMembers[0])
        return state
    }
}
