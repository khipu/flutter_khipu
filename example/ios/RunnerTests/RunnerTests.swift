import Flutter
import UIKit
import XCTest

@testable import flutter_khipu

// This is the Swift half of the status-mapping test that already exists on
// Android as `FlutterKhipuPluginTest.kt`'s `maps every status the SDK can
// emit` / `an unknown status degrades instead of throwing`. `statusOf` is
// written twice — once in Kotlin, once in Swift — and the two have to agree
// exactly. Without a test on this side, a status added to one and not the
// other stays green on both platforms while iOS silently reports it as
// `.unknown` and Android reports it correctly, so a merchant sees different
// behaviour per platform in production.
//
// See https://developer.apple.com/documentation/xctest for more information about using XCTest.

class RunnerTests: XCTestCase {

  func testStatusOfMapsTheFourKnownValues() {
    // One per terminal message of the protocol, measured on the bytecode of
    // khipu-client-android 2.28.5 (§ FlutterKhipuPlugin.kt); the native iOS
    // client emits the same four.
    XCTAssertEqual(FlutterKhipuPlugin.statusOf("OK"), .ok)
    XCTAssertEqual(FlutterKhipuPlugin.statusOf("ERROR"), .error)
    XCTAssertEqual(FlutterKhipuPlugin.statusOf("WARNING"), .warning)
    XCTAssertEqual(FlutterKhipuPlugin.statusOf("CONTINUE"), .mustContinue)
  }

  func testUserCanceledIsNotAResultAndIsNotMappedAsOne() {
    // Abandonment arrives as .error with failureReason "USER_CANCELED". 2.0.0
    // mapped USER_CANCELED to a status of its own, which no path could
    // produce. If it ever did reach this function it is an unrecognised value
    // like any other, and degrading is the right answer.
    XCTAssertEqual(FlutterKhipuPlugin.statusOf("USER_CANCELED"), .unknown)
  }

  func testStatusOfDegradesAnUnknownValueInsteadOfCrashing() {
    // This is the whole point of the unknown case: the day the server emits
    // a new value, the payment still has to reach the merchant.
    XCTAssertEqual(FlutterKhipuPlugin.statusOf("SOMETHING_NEW"), .unknown)
    XCTAssertEqual(FlutterKhipuPlugin.statusOf(""), .unknown)
  }

}
