import XCTest

final class FamilyRecipesUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Helper to ensure the app is logged in as '妈妈'.
    /// If not logged in, it creates '妈妈' if needed and taps the button.
    private func ensureLoggedInAsMama(app: XCUIApplication) {
        let todayOrderTab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "今日点餐")).firstMatch
        if !todayOrderTab.exists {
            let mamaButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "妈妈")).firstMatch
            if !mamaButton.waitForExistence(timeout: 3.0) {
                let addMemberButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "添加成员")).firstMatch
                XCTAssertTrue(addMemberButton.waitForExistence(timeout: 5.0), "添加成员 button should exist on ProfileSelectionView")
                addMemberButton.tap()
                
                let nameTextField = app.textFields["名字（例如：爸爸、宝贝）"]
                XCTAssertTrue(nameTextField.waitForExistence(timeout: 5.0), "Name text field should appear")
                nameTextField.tap()
                nameTextField.typeText("妈妈")
                
                let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "保存")).firstMatch
                XCTAssertTrue(saveButton.exists, "Save button should exist")
                saveButton.tap()
            }
            XCTAssertTrue(mamaButton.waitForExistence(timeout: 5.0), "妈妈 member button should be visible")
            mamaButton.tap()
        }
        XCTAssertTrue(todayOrderTab.waitForExistence(timeout: 5.0), "App should log in and transition to MainTabView")
    }

    func testFamilyMemberSwitcher() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Launch the app. If no members exist, tap '添加成员', type a name like '妈妈', choose '保存'.
        let mamaButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "妈妈")).firstMatch
        if !mamaButton.waitForExistence(timeout: 3.0) {
            let addMemberButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "添加成员")).firstMatch
            XCTAssertTrue(addMemberButton.waitForExistence(timeout: 5.0), "添加成员 button should exist")
            addMemberButton.tap()
            
            let nameTextField = app.textFields["名字（例如：爸爸、宝贝）"]
            XCTAssertTrue(nameTextField.waitForExistence(timeout: 5.0), "Name text field should exist")
            nameTextField.tap()
            nameTextField.typeText("妈妈")
            
            let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "保存")).firstMatch
            XCTAssertTrue(saveButton.exists, "Save button should exist")
            saveButton.tap()
        }
        
        // 2. Tap on the member button ('妈妈') to log in and transition to 'MainTabView'.
        XCTAssertTrue(mamaButton.waitForExistence(timeout: 5.0), "妈妈 member button should be visible")
        mamaButton.tap()
        
        // 3. Verify the tabs (e.g. '今日点餐', '共享菜谱') exist.
        let tabBars = app.tabBars
        let todayOrderTab = tabBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "今日点餐")).firstMatch
        let sharedRecipesTab = tabBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "共享菜谱")).firstMatch
        XCTAssertTrue(todayOrderTab.waitForExistence(timeout: 5.0), "今日点餐 tab should exist")
        XCTAssertTrue(sharedRecipesTab.exists, "共享菜谱 tab should exist")
        
        // 4. Tap the profile/role switcher button in the navigation bar trailing (which displays the active member's emoji and name).
        let logoutButton = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "妈妈")).firstMatch
        XCTAssertTrue(logoutButton.waitForExistence(timeout: 5.0), "Profile/role switcher button containing '妈妈' should exist in navigation bar")
        logoutButton.tap()
        
        // 5. Verify that it logs out and transitions back to the 'ProfileSelectionView' (where '添加成员' is visible).
        let addMemberButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "添加成员")).firstMatch
        XCTAssertTrue(addMemberButton.waitForExistence(timeout: 5.0), "Should transition back to ProfileSelectionView showing 添加成员")
    }

    func testAddNewRecipe() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Log in as a member (e.g. tap '妈妈' on 'ProfileSelectionView').
        ensureLoggedInAsMama(app: app)
        
        // 2. Navigate to the '共享菜谱' tab.
        let sharedRecipesTab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "共享菜谱")).firstMatch
        XCTAssertTrue(sharedRecipesTab.waitForExistence(timeout: 5.0), "共享菜谱 tab should be visible")
        sharedRecipesTab.tap()
        
        // 3. Tap the add button (with accessibility identifier 'addDishButton').
        let addButton = app.buttons["addDishButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5.0), "Add recipe button should exist")
        addButton.tap()
        
        // 4. In the '添加新菜品' sheet, fill the text field '菜品名字 (如: 番茄炒蛋)' with '红烧肉'.
        let nameField = app.textFields["菜品名字 (如: 番茄炒蛋)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5.0), "Dish name field should exist")
        nameField.tap()
        nameField.typeText("红烧肉")
        
        // 5. Fill the text field '一句话介绍（如：酸甜爽口）' with '经典红烧肉'.
        let descField = app.textFields["一句话介绍（如：酸甜爽口）"]
        XCTAssertTrue(descField.exists, "Description field should exist")
        descField.tap()
        descField.typeText("经典红烧肉")
        
        // 6. Fill the text field '标签（英文或中文逗号分隔，如：微辣, 清淡）' with '咸甜, 下饭'.
        let tagsField = app.textFields["标签（英文或中文逗号分隔，如：微辣, 清淡）"]
        XCTAssertTrue(tagsField.exists, "Tags field should exist")
        tagsField.tap()
        tagsField.typeText("咸甜, 下饭")
        
        // 7. Tap '保存'.
        let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "保存")).firstMatch
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        saveButton.tap()
        
        // 8. Verify that the dish '红烧肉' is successfully added and visible in the list.
        let dishText = app.staticTexts["红烧肉"]
        XCTAssertTrue(dishText.waitForExistence(timeout: 5.0), "Added dish '红烧肉' should be visible in the list")
    }

    func testLuckyWheelTransitions() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Log in as a member.
        ensureLoggedInAsMama(app: app)
        
        // 2. On the '今日点餐' tab, tap the '今天吃什么？' wheel card to present 'LuckyWheelView'.
        let todayOrderTab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "今日点餐")).firstMatch
        XCTAssertTrue(todayOrderTab.waitForExistence(timeout: 5.0), "今日点餐 tab should exist")
        todayOrderTab.tap()
        
        let wheelCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "今天吃什么？")).firstMatch
        XCTAssertTrue(wheelCard.waitForExistence(timeout: 5.0), "今天吃什么？ wheel card should exist")
        wheelCard.tap()
        
        // 3. Tap the '开始' button in the center of the wheel.
        let startButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "开始")).firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 5.0), "开始 button should exist in the center of the wheel")
        startButton.tap()
        
        // 4. Wait for the spin animation to complete (at least 4.5 seconds) and the result modal to appear.
        let resultHeader = app.staticTexts["🎉 选中美味啦！"]
        XCTAssertTrue(resultHeader.waitForExistence(timeout: 6.0), "Result modal should appear after the wheel stops spinning")
        
        // 5. Verify the result modal header ('🎉 选中美味啦！') and interactive buttons exist: '就是它了！立刻点单' and '手气不行，再转一次'.
        let confirmButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "就是它了！立刻点单")).firstMatch
        let tryAgainButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "手气不行，再转一次")).firstMatch
        XCTAssertTrue(confirmButton.exists, "'就是它了！立刻点单' button should exist")
        XCTAssertTrue(tryAgainButton.exists, "'手气不行，再转一次' button should exist")
        
        // 6. Tap '就是它了！立刻点单' and verify the modal/wheel dismisses, returning to '今日点餐'.
        confirmButton.tap()
        
        XCTAssertTrue(wheelCard.waitForExistence(timeout: 5.0), "Modal should dismiss and return to today's order panel")
    }
}
