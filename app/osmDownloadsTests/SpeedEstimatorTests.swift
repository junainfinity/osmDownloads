import XCTest
@testable import osmDownloads

final class SpeedEstimatorTests: XCTestCase {

    func testFirstTickReturnsZero() {
        var e = SpeedEstimator()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        XCTAssertEqual(e.tick(totalBytes: 0, now: t0), 0)
    }

    func testSecondTickReturnsInstantaneous() {
        var e = SpeedEstimator(alpha: 0.5)
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        _ = e.tick(totalBytes: 0, now: t0)
        let r = e.tick(totalBytes: 1000, now: t0.addingTimeInterval(1.0))
        XCTAssertEqual(r, 1000, accuracy: 0.5)
    }

    func testEMASmoothsAcrossTicks() {
        var e = SpeedEstimator(alpha: 0.5)
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        _ = e.tick(totalBytes: 0, now: t0)
        _ = e.tick(totalBytes: 1000, now: t0.addingTimeInterval(1.0))   // sets ema = 1000
        let r = e.tick(totalBytes: 3000, now: t0.addingTimeInterval(2.0))
        // instantaneous = 2000 bytes/s, alpha=0.5 → ema = 0.5*2000 + 0.5*1000 = 1500
        XCTAssertEqual(r, 1500, accuracy: 1)
    }

    func testIgnoresShortIntervals() {
        var e = SpeedEstimator()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        _ = e.tick(totalBytes: 0, now: t0)
        let r = e.tick(totalBytes: 1000, now: t0.addingTimeInterval(0.01))
        XCTAssertEqual(r, 0, "Sub-50ms ticks should hold the previous EMA, not produce huge bursts")
    }

    func testNeverNegative() {
        var e = SpeedEstimator()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        _ = e.tick(totalBytes: 1000, now: t0)
        let r = e.tick(totalBytes: 500, now: t0.addingTimeInterval(1.0))   // bytes went down, e.g. resume reset
        XCTAssertGreaterThanOrEqual(r, 0)
    }
}
