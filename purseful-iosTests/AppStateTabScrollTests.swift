import Foundation
import Testing
@testable import purseful_ios

@MainActor
struct AppStateTabScrollTests {
    @Test func selectingDifferentTabChangesSelectionWithoutScrollToken() {
        let state = AppState()
        state.selectedTab = 0

        state.selectTab(1)

        #expect(state.selectedTab == 1)
        #expect(state.tabScrollToken(for: 0) == 0)
        #expect(state.tabScrollToken(for: 1) == 0)
    }

    @Test func requestScrollToTopIncrementsTokenForSelectedTab() {
        let state = AppState()
        state.selectedTab = 2

        state.requestScrollToTop(for: 2)

        #expect(state.tabScrollToken(for: 2) == 1)
    }

    @Test func rapidReselectIsDebounced() {
        let state = AppState()
        state.selectedTab = 0

        state.requestScrollToTop(for: 0)
        state.requestScrollToTop(for: 0)

        #expect(state.tabScrollToken(for: 0) == 1)
    }

    @Test func scrollRequestIgnoredForNonSelectedTab() {
        let state = AppState()
        state.selectedTab = 0

        state.requestScrollToTop(for: 3)

        #expect(state.tabScrollToken(for: 3) == 0)
    }
}
