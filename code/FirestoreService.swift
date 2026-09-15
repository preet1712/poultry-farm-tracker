import Foundation
import FirebaseFirestore

// MARK: - App Errors

enum AppError: LocalizedError {
    case missingDocumentId

    var errorDescription: String? {
        switch self {
        case .missingDocumentId:
            return "Document ID is missing. Please try again."
        }
    }
}

// MARK: - FirestoreService

final class FirestoreService {

    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Batches

    func fetchBatches(status: BatchStatus) async throws -> [Batch] {
        // No .order(by:) here — combining whereField + orderBy on different fields
        // requires a composite index. We sort client-side instead.
        let snapshot = try await db.collection("batches")
            .whereField("status", isEqualTo: status.rawValue)
            .getDocuments()
        return try snapshot.documents
            .map { try $0.data(as: Batch.self) }
            .sorted { lhs, rhs in
                let lhsOrder = lhs.sortOrder ?? 0
                let rhsOrder = rhs.sortOrder ?? 0
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return lhs.createdAt > rhs.createdAt
            }
    }

    func createBatch(_ batch: Batch) async throws {
        _ = try db.collection("batches").addDocument(from: batch)
    }

    func updateBatch(_ batch: Batch) async throws {
        guard let id = batch.id else { throw AppError.missingDocumentId }
        try db.collection("batches").document(id).setData(from: batch)
    }

    func updateBatchStatus(id: String, status: BatchStatus) async throws {
        try await db.collection("batches").document(id).updateData([
            "status": status.rawValue
        ])
    }

    // MARK: - Daily Records

    func fetchDailyRecords(for batchId: String) async throws -> [DailyRecord] {
        let snapshot = try await db.collection("batches")
            .document(batchId)
            .collection("dailyRecords")
            .order(by: "date", descending: true)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: DailyRecord.self) }
    }

    func fetchLatestRecord(for batchId: String) async throws -> DailyRecord? {
        let snapshot = try await db.collection("batches")
            .document(batchId)
            .collection("dailyRecords")
            .order(by: "date", descending: true)
            .limit(to: 1)
            .getDocuments()
        return try snapshot.documents.first.map { try $0.data(as: DailyRecord.self) }
    }

    func createDailyRecord(_ record: DailyRecord, for batchId: String) async throws {
        _ = try db.collection("batches")
            .document(batchId)
            .collection("dailyRecords")
            .addDocument(from: record)
    }

    func updateDailyRecord(_ record: DailyRecord, batchId: String) async throws {
        guard let id = record.id else { throw AppError.missingDocumentId }
        try db.collection("batches")
            .document(batchId)
            .collection("dailyRecords")
            .document(id)
            .setData(from: record)
    }

    func hasRecordForDate(_ date: Date, batchId: String) async throws -> Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return false }

        let snapshot = try await db.collection("batches")
            .document(batchId)
            .collection("dailyRecords")
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("date", isLessThan: Timestamp(date: end))
            .getDocuments()
        return !snapshot.documents.isEmpty
    }

    func updateBatchSortOrders(_ updates: [(id: String, sortOrder: Int)]) async throws {
        let writeBatch = db.batch()
        for update in updates {
            let ref = db.collection("batches").document(update.id)
            writeBatch.updateData(["sortOrder": update.sortOrder], forDocument: ref)
        }
        try await writeBatch.commit()
    }

    // MARK: - Sales

    func fetchSales() async throws -> [SaleRecord] {
        // billNumber is a string ("13", "13T") — Firestore would sort it
        // lexicographically, so we sort client-side by numeric value instead.
        let snapshot = try await db.collection("sales").getDocuments()
        return try snapshot.documents
            .map { try $0.data(as: SaleRecord.self) }
            .sorted { lhs, rhs in
                if lhs.numericBillNumber != rhs.numericBillNumber {
                    return lhs.numericBillNumber > rhs.numericBillNumber
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    func createSale(_ sale: SaleRecord) async throws {
        _ = try db.collection("sales").addDocument(from: sale)
    }

    func updateSale(_ sale: SaleRecord) async throws {
        guard let id = sale.id else { throw AppError.missingDocumentId }
        try db.collection("sales").document(id).setData(from: sale)
    }

    func deleteSale(_ sale: SaleRecord) async throws {
        guard let id = sale.id else { throw AppError.missingDocumentId }
        try await db.collection("sales").document(id).delete()
    }

    func totalDeaths(for batchId: String) async throws -> Int {
        let records = try await fetchDailyRecords(for: batchId)
        return records.reduce(0) { $0 + $1.dailyDeaths }
    }
}
