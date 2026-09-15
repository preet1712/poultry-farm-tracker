import Foundation

// MARK: - DailyRecordWithContext
// A DailyRecord enriched with computed values that require the full record history
// (running chicken count, production rate, age at that date).

struct DailyRecordWithContext: Identifiable, Hashable {
    let id: String          // Stable Firestore document ID (or UUID fallback)
    let record: DailyRecord
    let currentChickenCount: Int    // chickensPurchased − cumulative deaths up to this record
    let productionRate: Double      // eggsCollected / currentChickenCount * 100
    let ageInWeeks: Int             // age of batch on this record's date
    let layingWeek: Int?            // ageInWeeks − 20, nil if < 20

    init(record: DailyRecord, currentChickenCount: Int, productionRate: Double, ageInWeeks: Int, layingWeek: Int?) {
        self.id = record.id ?? UUID().uuidString
        self.record = record
        self.currentChickenCount = currentChickenCount
        self.productionRate = productionRate
        self.ageInWeeks = ageInWeeks
        self.layingWeek = layingWeek
    }
}

extension DailyRecordWithContext {
    static func == (lhs: DailyRecordWithContext, rhs: DailyRecordWithContext) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - WeekData
// Aggregated statistics for one calendar week of a batch's life.

struct WeekData: Identifiable {
    var id: Int { weekNumber }       // Week number is stable and unique per batch
    let weekNumber: Int              // Age of batch in weeks at start of this week
    let layingWeek: Int?
    let records: [DailyRecordWithContext]

    var totalEggs: Int      { records.reduce(0) { $0 + $1.record.eggsCollected } }
    var totalDeaths: Int    { records.reduce(0) { $0 + $1.record.dailyDeaths } }
    var totalTrays: Double  { Double(totalEggs) / 30.0 }
    var daysRecorded: Int   { records.count }

    var averageProductionRate: Double {
        guard !records.isEmpty else { return 0 }
        return records.map(\.productionRate).reduce(0, +) / Double(records.count)
    }

    var averageDailyEggs: Double {
        guard !records.isEmpty else { return 0 }
        return Double(totalEggs) / Double(records.count)
    }

    var endingChickenCount: Int {
        records.last?.currentChickenCount ?? 0
    }
}

// MARK: - ToDateStats
// Cumulative statistics from batch start to today.

struct ToDateStats {
    let totalEggs: Int
    let totalTrays: Double
    let totalDeaths: Int
    let currentChickenCount: Int
    let averageProductionRate: Double   // mean of daily production rates
    let mortalityRatio: Double          // totalDeaths / chickensPurchased * 100
    let eggsPerChickenRatio: Double     // totalEggs / chickensPurchased
    let daysActive: Int                 // days since purchase date
    let daysRecorded: Int               // number of days with an entry
}
