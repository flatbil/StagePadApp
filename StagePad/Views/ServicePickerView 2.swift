import SwiftUI

struct ServicePickerView: View {
    @EnvironmentObject var pc: PlanningCenterService
    @Environment(\.dismiss) private var dismiss

    private var upcoming: [PCPlanSummary] {
        pc.availablePlans.filter { $0.sortDate >= Date().addingTimeInterval(-86400) }
    }
    private var past: [PCPlanSummary] {
        pc.availablePlans.filter { $0.sortDate < Date().addingTimeInterval(-86400) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if pc.isLoadingPlans {
                    ProgressView().tint(.white)
                } else {
                    planList
                }
            }
            .navigationTitle("Load a Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await pc.fetchAvailablePlans() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .task {
            if pc.availablePlans.isEmpty { await pc.fetchAvailablePlans() }
        }
        .preferredColorScheme(.dark)
    }

    private var planList: some View {
        List {
            if !upcoming.isEmpty {
                Section {
                    ForEach(upcoming) { plan in
                        planRow(plan: plan)
                    }
                } header: {
                    sectionHeader("UPCOMING")
                }
            }
            if !past.isEmpty {
                Section {
                    ForEach(past) { plan in
                        planRow(plan: plan)
                    }
                } header: {
                    sectionHeader("RECENT")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.black)
    }

    private func planRow(plan: PCPlanSummary) -> some View {
        let isCurrent = pc.currentPlan?.id == plan.id
        return Button {
            Task {
                await pc.loadPlan(id: plan.id)
                dismiss()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isCurrent ? "checkmark.circle.fill" : "calendar")
                    .font(.system(size: 18))
                    .foregroundStyle(isCurrent ? .green : .white.opacity(0.3))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 15, weight: isCurrent ? .bold : .medium, design: .rounded))
                        .foregroundStyle(.white)
                    Text(plan.dates)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                if pc.isLoading && isCurrent {
                    ProgressView().tint(.white).scaleEffect(0.7)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            .padding(.vertical, 6)
        }
        .listRowBackground(isCurrent ? Color.green.opacity(0.08) : Color.clear)
        .listRowSeparatorTint(.white.opacity(0.08))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.35))
            .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 4, trailing: 0))
    }
}
