import XCTest

final class FamilyRecipesUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Helper to ensure the app is logged in as '妈妈'.
    /// If not logged in, it creates '妈妈' if needed and taps the button.
    private func ensureLoggedInAsMama(app: XCUIApplication) {
        let todayOrderTab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "今日点餐")).firstMatch
        if todayOrderTab.waitForExistence(timeout: 2.0) {
            return
        }
        
        let mamaButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "妈妈")).firstMatch
        if mamaButton.waitForExistence(timeout: 3.0) {
            mamaButton.tap()
        } else {
            let addMemberButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "添加成员")).firstMatch
            if addMemberButton.waitForExistence(timeout: 4.0) {
                addMemberButton.tap()
                
                let nameTextField = app.textFields["名字（例如：爸爸、宝贝）"]
                if nameTextField.waitForExistence(timeout: 3.0) {
                    nameTextField.tap()
                    nameTextField.typeText("妈妈")
                }
                
                let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "保存")).firstMatch
                if saveButton.waitForExistence(timeout: 3.0) {
                    saveButton.tap()
                }
            }
            if mamaButton.waitForExistence(timeout: 5.0) {
                mamaButton.tap()
            }
        }
        _ = todayOrderTab.waitForExistence(timeout: 5.0)
    }

    func testFamilyMemberSwitcher() throws {
        let app = XCUIApplication()
        app.launch()

        let todayOrderTab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "今日点餐")).firstMatch
        if todayOrderTab.waitForExistence(timeout: 2.0) {
            // Already logged in, tap profile button in nav bar to log out first
            let logoutButton = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "妈妈")).firstMatch
            if logoutButton.waitForExistence(timeout: 3.0) {
                logoutButton.tap()
            }
        }

        // 1. On ProfileSelectionView, find '妈妈' or tap '添加成员'
        let mamaButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "妈妈")).firstMatch
        if !mamaButton.waitForExistence(timeout: 3.0) {
            let addMemberButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "添加成员")).firstMatch
            if addMemberButton.waitForExistence(timeout: 4.0) {
                addMemberButton.tap()
                
                let nameTextField = app.textFields["名字（例如：爸爸、宝贝）"]
                if nameTextField.waitForExistence(timeout: 3.0) {
                    nameTextField.tap()
                    nameTextField.typeText("妈妈")
                }
                
                let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "保存")).firstMatch
                if saveButton.waitForExistence(timeout: 3.0) {
                    saveButton.tap()
                }
            }
        }
        
        // 2. Tap on the member button ('妈妈') to log in and transition to 'MainTabView'.
        if mamaButton.waitForExistence(timeout: 5.0) {
            mamaButton.tap()
        }
        
        // 3. Verify the tabs (e.g. '今日点餐', '共享菜谱') exist.
        let tabBars = app.tabBars
        let orderTab = tabBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "今日点餐")).firstMatch
        let sharedRecipesTab = tabBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "共享菜谱")).firstMatch
        XCTAssertTrue(orderTab.waitForExistence(timeout: 5.0), "今日点餐 tab should exist")
        XCTAssertTrue(sharedRecipesTab.exists, "共享菜谱 tab should exist")
        
        // 4. Tap the profile/role switcher button in the navigation bar trailing
        let profileBtn = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "妈妈")).firstMatch
        if profileBtn.waitForExistence(timeout: 5.0) {
            profileBtn.tap()
            
            // 5. Verify that it logs out and transitions back to ProfileSelectionView
            let addMemberBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "添加成员")).firstMatch
            XCTAssertTrue(addMemberBtn.waitForExistence(timeout: 5.0), "Should transition back to ProfileSelectionView showing 添加成员")
        }
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

    func testCaptureSharedRecipesScreenshot() throws {
        let app = XCUIApplication()
        app.launch()
        
        let sharedRecipesTab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "共享菜谱")).firstMatch
        if sharedRecipesTab.waitForExistence(timeout: 5.0) {
            sharedRecipesTab.tap()
        } else {
            let anyMember = app.buttons.firstMatch
            if anyMember.waitForExistence(timeout: 3.0) {
                anyMember.tap()
                let tab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "共享菜谱")).firstMatch
                if tab.waitForExistence(timeout: 5.0) {
                    tab.tap()
                }
            }
        }
        
        sleep(2)
        let screenshot = app.screenshot()
        let path = "/Users/zhangzhihao/Documents/project/recipes/scratch/shared_recipes_screen.png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
    }
}
