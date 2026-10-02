import XCTest
@testable import BeckifyMath

final class SavedJobsArchiveTests: XCTestCase {
    func testArchiveRoundTripsCodeBasisAndDates() throws {
        let record = sampleJob()
        let archive = SavedJobsArchive(
            exportedAt: Date(timeIntervalSince1970: 1_750_000_000),
            jobs: [record]
        )

        let decoded = try SavedJobsArchive.decode(archive.encodedData())

        XCTAssertEqual(decoded, archive)
    }

    func testArchiveRejectsUnsupportedVersion() throws {
        let archive = SavedJobsArchive(schemaVersion: 2, jobs: [sampleJob()])
        XCTAssertThrowsError(try archive.encodedData()) {
            XCTAssertEqual($0 as? SavedJobsArchiveError, .unsupportedVersion(2))
        }
    }

    func testArchiveRejectsDuplicateIDs() throws {
        let job = sampleJob()
        var caseVariant = job
        caseVariant.id = job.id.uppercased()
        let archive = SavedJobsArchive(jobs: [job, caseVariant])
        XCTAssertThrowsError(try archive.encodedData()) {
            XCTAssertEqual(
                $0 as? SavedJobsArchiveError,
                .invalidJob("A saved note has an invalid or duplicate ID.")
            )
        }
    }

    func testArchiveRejectsUnknownToolAndUnboundedFields() throws {
        var job = sampleJob()
        job.toolID = "unknownTool"
        XCTAssertThrowsError(try SavedJobsArchive(jobs: [job]).encodedData())

        job = sampleJob()
        job.outputs = ["result": String(repeating: "x", count: 8_001)]
        XCTAssertThrowsError(try SavedJobsArchive(jobs: [job]).encodedData())
    }

    func testArchiveRejectsOversizedInput() {
        let data = Data(repeating: 0, count: SavedJobsArchive.maximumFileSize + 1)
        XCTAssertThrowsError(try SavedJobsArchive.decode(data)) {
            XCTAssertEqual($0 as? SavedJobsArchiveError, .fileTooLarge)
        }
    }

    func testArchiveRejectsAggregatePayloadOverLimitBeforeEncoding() {
        let jobs = (0..<1_100).map { index in
            var job = sampleJob()
            job.id = UUID().uuidString
            job.outputs = ["result": String(repeating: "x", count: 8_000)]
            job.name = "Saved note \(index)"
            return job
        }
        XCTAssertThrowsError(try SavedJobsArchive(jobs: jobs).encodedData()) {
            XCTAssertEqual($0 as? SavedJobsArchiveError, .fileTooLarge)
        }
    }

    private func sampleJob() -> SavedJobArchiveRecord {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        return SavedJobArchiveRecord(
            id: "a5d9e8f3-60f6-4e83-ae5d-6fef7c53c642",
            name: "Feeder check",
            toolID: "voltageDrop",
            notes: "Reviewed on site",
            calculationBasis: "Code: NEC (US). Default.",
            inputs: ["current": "32"],
            outputs: ["drop": "2.1 V"],
            createdAt: date,
            updatedAt: date
        )
    }
}
