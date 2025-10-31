//
//  LinkUITests.swift
//  LinkUITests
//

import XCTest

final class LinkUITests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-disableAnimations"]
        app.launch()
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testAll() throws {
        startTest()
        loadingTest()
        searchResultTest()
        linkListTest()
    }
    
    func startTest() {
        let searchByURLText = app.staticTexts["search-by-url-text"]
        let pastAURLTextfield = app.textFields["paste-a-url-textfield"]
        let searchButton = app.buttons["search-button"]
        let buttonSearchLabel = app.staticTexts["button-search-label"]
        let emptyText = app.staticTexts["link_section_view_empty"]
        
        XCTAssertTrue(searchByURLText.waitForExistence(timeout: 0.3), "Search By URL Text must exist")
        XCTAssertTrue(pastAURLTextfield.exists, "Past a URL Text Field must exist")
        XCTAssertTrue(searchButton.exists, "Search button must exist")
        XCTAssertTrue(buttonSearchLabel.exists, "Button Search Label exist")
        XCTAssertTrue(emptyText.exists, "Empty Text must exist")
    }
    
    func loadingTest() {
        app.open(URL(string: "link://ui/set?loading=on")!)
        
        let buttonSearchingText = app.staticTexts["button-searching-text"]
        let searchResultSearchingText = app.staticTexts["search_result_searching_text"]
        let searchResultCancelButton = app.buttons["search_result_cancel_button"]
        
        XCTAssertTrue(buttonSearchingText.waitForExistence(timeout: 0.3), "Button Searching Text must exist")
        XCTAssertTrue(searchResultSearchingText.exists, "Search Result Searching Text must exist")
        XCTAssertTrue(searchResultCancelButton.exists, "Search Result Cancel Button must exist")
    }
    
    func searchResultTest() {
        app.open(URL(string: "link://ui/search?id=123456&title=Exemple&url=https://example.com")!)
        
        let searchResultTitleText = app.staticTexts["search_result_title_text"]
        let searchResultURLText = app.staticTexts["search_result_url_text"]
        let searchResultSaveButton = app.buttons["search_result_save_button"]
        let searchResultOpenButton = app.buttons["search_result_open_button"]
        let searchResultClearButton = app.buttons["search_result_clear_button"]
        
        XCTAssertTrue(searchResultTitleText.waitForExistence(timeout: 0.3), "Search Result Title Text must exist")
        XCTAssertTrue(searchResultURLText.exists, "Search Result URL Text must exist")
        XCTAssertTrue(searchResultSaveButton.exists, "Search Result Save Button must exist")
        XCTAssertTrue(searchResultOpenButton.exists, "Search Result Open Button must exist")
        XCTAssertTrue(searchResultClearButton.exists, "Search Result Clear Button must exist")
    }
    
    func linkListTest() {
        app.open(URL(string: "link://ui/insert?id=123456&title=Exemple&url=https://example.com")!)
        
        let linkRowIcon = app.images["link_row_icon"]
        let linkRowTitle = app.staticTexts["link_row_title"]
        let linkRowURL = app.staticTexts["link_row_url"]
        
        XCTAssertTrue(linkRowIcon.waitForExistence(timeout: 0.3), "Link Row Icon must exist")
        XCTAssertTrue(linkRowTitle.exists, "Link Row Title must exist")
        XCTAssertTrue(linkRowURL.exists, "Link Row URL must exist")
    }
}
