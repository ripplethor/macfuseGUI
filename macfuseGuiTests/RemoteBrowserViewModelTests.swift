import XCTest
@testable import macfuseGui

final class RemoteBrowserViewModelTests: XCTestCase {
    func testPolledHealthReturnsReadyStateAfterHealthyRecoveryWithCachedEntries() {
        let health = BrowserConnectionHealth(
            state: .healthy,
            retryCount: 0,
            lastError: nil,
            lastSuccessAt: Date(),
            lastLatencyMs: 12,
            updatedAt: Date()
        )

        let projection = RemoteBrowserViewModel.projectPolledHealth(
            health,
            currentViewState: .degradedWithCache,
            hasEntries: true,
            isConfirmedEmpty: false,
            isStale: true,
            statusMessage: "Connection lost. Reconnecting..."
        )

        XCTAssertEqual(projection.viewState, .ready)
        XCTAssertFalse(projection.isStale)
        XCTAssertNil(projection.statusMessage)
    }

    func testPolledHealthKeepsFatalStateWhenHealthyPingHasNoBrowsableDataYet() {
        let health = BrowserConnectionHealth(
            state: .healthy,
            retryCount: 0,
            lastError: nil,
            lastSuccessAt: Date(),
            lastLatencyMs: 8,
            updatedAt: Date()
        )

        let projection = RemoteBrowserViewModel.projectPolledHealth(
            health,
            currentViewState: .fatal,
            hasEntries: false,
            isConfirmedEmpty: false,
            isStale: true,
            statusMessage: "Unable to load this path."
        )

        XCTAssertEqual(projection.viewState, .fatal)
        XCTAssertFalse(projection.isStale)
        XCTAssertNil(projection.statusMessage)
    }
}
