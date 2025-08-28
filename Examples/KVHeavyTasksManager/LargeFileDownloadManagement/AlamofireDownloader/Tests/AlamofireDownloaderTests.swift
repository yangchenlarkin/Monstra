import XCTest
@testable import AlamofireDownloader

final class AlamofireDownloaderTests: XCTestCase {
    
    func testDownloadProgressCalculation() {
        let progress = DownloadProgress(bytesDownloaded: 50, totalBytes: 100)
        XCTAssertEqual(progress.percentage, 50.0)
        XCTAssertEqual(progress.bytesDownloaded, 50)
        XCTAssertEqual(progress.totalBytes, 100)
    }
    
    func testDownloadProgressWithZeroTotal() {
        let progress = DownloadProgress(bytesDownloaded: 0, totalBytes: 0)
        XCTAssertEqual(progress.percentage, 0.0)
    }
    
    func testDownloadResultCreation() {
        let fileURL = URL(fileURLWithPath: "/test/file.txt")
        let result = DownloadResult(
            fileURL: fileURL,
            fileSize: 1024,
            downloadTime: 2.5,
            success: true,
            error: nil
        )
        
        XCTAssertEqual(result.fileURL, fileURL)
        XCTAssertEqual(result.fileSize, 1024)
        XCTAssertEqual(result.downloadTime, 2.5)
        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
    }
    
    func testDownloadErrorDescriptions() {
        let invalidURLError = DownloadError.invalidURL
        XCTAssertEqual(invalidURLError.errorDescription, "Invalid URL provided")
        
        let managerDeallocatedError = DownloadError.managerDeallocated
        XCTAssertEqual(managerDeallocatedError.errorDescription, "Download manager was deallocated")
    }
    
    static var allTests = [
        ("testDownloadProgressCalculation", testDownloadProgressCalculation),
        ("testDownloadProgressWithZeroTotal", testDownloadProgressWithZeroTotal),
        ("testDownloadResultCreation", testDownloadResultCreation),
        ("testDownloadErrorDescriptions", testDownloadErrorDescriptions)
    ]
}
