import SwiftUI

struct PlanView: View {
    @EnvironmentObject var pc: PlanningCenterService
    @EnvironmentObject var bridge: BridgeService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if pc.isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let error = pc.error {
                    errorView(message: error)
                } else if let plan = pc.currentPlan {
                    planContent(plan: plan)
                } else {
                    emptyView
                }
            }
            .navigationTitle("Service Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await pc.fetchCurrentPlan() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .task {
            if pc.currentPlan == nil { await pc.fetchCurrentPlan() }
        }
        .preferredColorScheme(.dark)
    }

    private func planContent(plan: PCServicePlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                planHeader(plan: plan)
                Divider().background(.white.opacity(0.1))
                ForEach(plan.songs) { song in
                    NavigationLink(destination: SongChartView(
                        song: song,
                        currentSectionLabel: currentSectionLabel(for: song)
                    )) {
                        songRow(song: song)
                    }
                    Divider().background(.white.opacity(0.07)).padding(.leading, 20)
                }
            }
        }
    }

    private func planHeader(plan: PCServicePlan) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(plan.dates)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func songRow(song: PCSong) -> some View {
        let isActive = bridge.songs.indices.contains(bridge.currentSongIndex) &&
                       bridge.songs[bridge.currentSongIndex].name.lowercased()
                           .contains(song.title.lowercased())
        let sectionLabel = currentSectionLabel(for: song)
        let nextSection: PCSection? = {
            guard isActive, !sectionLabel.isEmpty else { return nil }
            return pc.nextSection(after: sectionLabel, in: song)
        }()

        return HStack(spacing: 14) {
            Image(systemName: "music.note")
                .font(.system(size: 16))
                .foregroundStyle(isActive ? .green : .white.opacity(0.3))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(song.title)
                        .font(.system(size: 16, weight: isActive ? .bold : .medium, design: .rounded))
                        .foregroundStyle(.white)
                    if !song.key.isEmpty {
                        Text(song.key)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }

                if isActive && !sectionLabel.isEmpty {
                    HStack(spacing: 6) {
                        Text("NOW: \(sectionLabel)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.green)
                        if let next = nextSection {
                            Text("→ \(next.displayName)")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundStyle(.orange)
                        }
                    }
                } else {
                    Text("\(song.sections.count) sections")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            Spacer()

            if song.bpm > 0 {
                Text("\(Int(song.bpm)) BPM")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(isActive ? Color.green.opacity(0.06) : Color.clear)
    }

    private func currentSectionLabel(for song: PCSong) -> String {
        guard bridge.songs.indices.contains(bridge.currentSongIndex),
              bridge.songs[bridge.currentSongIndex].name.lowercased().contains(song.title.lowercased()),
              bridge.songs[bridge.currentSongIndex].sections.indices.contains(bridge.currentSectionIndex)
        else { return "" }
        return bridge.songs[bridge.currentSongIndex].sections[bridge.currentSectionIndex].name
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await pc.fetchCurrentPlan() } }
                .foregroundStyle(.white)
        }
        .padding(40)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.3))
            Text("No upcoming service found")
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}
