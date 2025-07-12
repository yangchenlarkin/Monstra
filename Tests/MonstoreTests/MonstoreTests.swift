//
//  MonstoreTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/5/8.
//

import XCTest
@testable import Monstore

final class MonstoreTests: XCTestCase {
    func testSet() throws {
        let a = Monstore<String, String>()
        a.set("", for: "")
    }
}
