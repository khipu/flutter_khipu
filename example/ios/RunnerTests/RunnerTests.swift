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

  func testStatusOfMapsTheFiveKnownValues() {
    // The five values khipu-client-android 2.28.5 can emit, measured on its
    // bytecode (§ FlutterKhipuPlugin.kt); the native iOS client emits the
    // same five.
    XCTAssertEqual(FlutterKhipuPlugin.statusOf("OK"), .ok)
    XCTAssertEqual(FlutterKhipuPlugin.statusOf("ERROR"), .error)
    XCTAssertEqual(FlutterKhipuPlugin.statusOf("WARNING"), .warning)
    XCTAssertEqual(FlutterKhipuPlugin.statusOf("CONTINUE"), .mustContinue)
    XCTAssertEqual(FlutterKhipuPlugin.statusOf("USER_CANCELED"), .userCanceled)
  }

  func testStatusOfDegradesAnUnknownValueInsteadOfCrashing() {
    // This is the whole point of the unknown case: the day the server emits
    // a new value, the payment still has to reach the merchant.
    XCTAssertEqual(FlutterKhipuPlugin.statusOf("SOMETHING_NEW"), .unknown)
    XCTAssertEqual(FlutterKhipuPlugin.statusOf(""), .unknown)
  }

}
