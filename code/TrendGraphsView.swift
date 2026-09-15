import SwiftUI
import Charts

struct TrendGraphsView: View {
    @ObservedObject var viewModel: BatchDetailViewModel
    @State private var selectedWeekRate: Int?
    @State private var selectedWeekEggs: Int?
    @State private var selectedWeekMort: Int?

    var body: some View {
        if viewModel.weeklyData.isEmpty {
            noDataView
        } else {
            List {
                chartSection(
                    title: "Avg Production Rate",
                    subtitle: "% of live chickens producing eggs per week"
                ) {
                    productionRateChart
                }

                chartSection(
                    title: "Weekly Egg Count",
                    subtitle: "Total eggs collected per week"
                ) {
                    eggCountChart
                }

                chartSection(
                    title: "Weekly Deaths",
                    subtitle: "Total deaths recorded per week"
                ) {
                    mortalityChart
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Section Wrapper

    private func chartSection<C: View>(title: String, subtitle: String, @ViewBuilder chart: () -> C) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                chart().frame(height: 200).padding(.vertical, 8)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        } header: {
            Text(title)
        }
    }

    // MARK: - Production Rate Line Chart

    private var productionRateChart: some View {
        Chart {
            ForEach(viewModel.weeklyData) { week in
                LineMark(
                    x: .value("Week", week.weekNumber),
                    y: .value("Rate %", week.averageProductionRate)
                )
                .foregroundStyle(Color.blue)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Week", week.weekNumber),
                    y: .value("Rate %", week.averageProductionRate)
                )
                .foregroundStyle(Color.blue.opacity(0.1))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Week", week.weekNumber),
                    y: .value("Rate %", week.averageProductionRate)
                )
                .foregroundStyle(Color.blue)
                .symbolSize(30)
            }

            if let sel = selectedWeekRate,
               let week = viewModel.weeklyData.first(where: { $0.weekNumber == sel }) {
                selectionRule(week: sel, label: String(format: "%.1f%%", week.averageProductionRate))
            }
        }
        .chartXScale(domain: weekDomain)
        .chartYScale(domain: 0...max(100, (viewModel.weeklyData.map(\.averageProductionRate).max() ?? 100) * 1.1))
        .chartXAxis { weekAxisMarks }
        .chartYAxis {
            AxisMarks(values: .automatic) { v in
                AxisGridLine()
                AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))%").font(.caption2) } }
            }
        }
        .chartInteraction(selection: $selectedWeekRate, data: viewModel.weeklyData)
    }

    // MARK: - Egg Count Line Chart

    private var eggCountChart: some View {
        Chart {
            ForEach(viewModel.weeklyData) { week in
                LineMark(
                    x: .value("Week", week.weekNumber),
                    y: .value("Eggs", week.totalEggs)
                )
                .foregroundStyle(Color.farmGreen)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Week", week.weekNumber),
                    y: .value("Eggs", week.totalEggs)
                )
                .foregroundStyle(Color.farmGreen.opacity(0.1))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Week", week.weekNumber),
                    y: .value("Eggs", week.totalEggs)
                )
                .foregroundStyle(Color.farmGreen)
                .symbolSize(30)
            }

            if let sel = selectedWeekEggs,
               let week = viewModel.weeklyData.first(where: { $0.weekNumber == sel }) {
                selectionRule(week: sel, label: "\(week.totalEggs) eggs")
            }
        }
        .chartXAxis { weekAxisMarks }
        .chartYAxis {
            AxisMarks(values: .automatic) { v in
                AxisGridLine()
                AxisValueLabel { if let d = v.as(Int.self) { Text("\(d)").font(.caption2) } }
            }
        }
        .chartXScale(domain: weekDomain)
        .chartInteraction(selection: $selectedWeekEggs, data: viewModel.weeklyData)
    }

    // MARK: - Mortality Bar Chart

    private var mortalityChart: some View {
        Chart {
            ForEach(viewModel.weeklyData) { week in
                BarMark(
                    x: .value("Week", week.weekNumber),
                    y: .value("Deaths", week.totalDeaths)
                )
                .foregroundStyle(
                    selectedWeekMort == week.weekNumber
                        ? Color.red.opacity(0.9)
                        : Color.red.opacity(0.55)
                )
                .cornerRadius(4)
            }

            if let sel = selectedWeekMort,
               let week = viewModel.weeklyData.first(where: { $0.weekNumber == sel }) {
                selectionRule(week: sel, label: "\(week.totalDeaths) deaths")
            }
        }
        .chartXAxis { weekAxisMarks }
        .chartYAxis {
            AxisMarks(values: .automatic) { v in
                AxisGridLine()
                AxisValueLabel { if let d = v.as(Int.self) { Text("\(d)").font(.caption2) } }
            }
        }
        .chartXScale(domain: weekDomain)
        .chartInteraction(selection: $selectedWeekMort, data: viewModel.weeklyData)
    }

    // MARK: - Shared chart helpers

    private var weekDomain: ClosedRange<Int> {
        let min = viewModel.weeklyData.first?.weekNumber ?? 1
        let max = viewModel.weeklyData.last?.weekNumber ?? 1
        return min...max
    }

    @AxisContentBuilder
    private var weekAxisMarks: some AxisContent {
        AxisMarks(values: .automatic) { value in
            AxisGridLine()
            AxisValueLabel {
                if let w = value.as(Int.self) { Text("W\(w)").font(.caption2) }
            }
        }
    }

    @ChartContentBuilder
    private func selectionRule(week: Int, label: String) -> some ChartContent {
        RuleMark(x: .value("Week", week))
            .foregroundStyle(.secondary.opacity(0.3))

            .annotation(position: .top, spacing: 4) {
                Text(label)
                    .font(.caption).fontWeight(.semibold)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(radius: 2)
            }
    }

    // MARK: - Empty State

    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 52)).foregroundStyle(.tertiary)
            Text("No Data Yet").font(.title3).fontWeight(.semibold)
            Text("Trend graphs appear once daily entries are added.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Chart Interaction Modifier
// Adds tap/drag selection to any chart using chartOverlay.

extension View {
    func chartInteraction(selection: Binding<Int?>, data: [WeekData]) -> some View {
        self.chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let origin = geo[proxy.plotAreaFrame].origin
                                let xPos = drag.location.x - origin.x
                                guard xPos >= 0, xPos < proxy.plotAreaSize.width else { return }
                                if let week: Int = proxy.value(atX: xPos, as: Int.self) {
                                    // Snap to nearest actual week
                                    let nearest = data.min(by: { abs($0.weekNumber - week) < abs($1.weekNumber - week) })
                                    selection.wrappedValue = nearest?.weekNumber
                                }
                            }
                            .onEnded { _ in selection.wrappedValue = nil }
                    )
            }
        }
    }
}
