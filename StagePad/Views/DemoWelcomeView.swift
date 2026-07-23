import SwiftUI

struct DemoWelcomeView: View {
    @Binding var isPresented: Bool
    @State private var page = 0

    private struct TourStep {
        let icon: String
        let title: String
        let description: String
    }

    private let tourSteps: [TourStep] = [
        TourStep(
            icon: "info.circle.fill",
            title: "Info Bar",
            description: "Shows the current song, section, tempo, and bar number. The colored dot is your bridge connection status — green means live. Tap the gear icon to open Settings."
        ),
        TourStep(
            icon: "list.bullet.rectangle",
            title: "Song Selector",
            description: "Tap any song to select it and see its sections below. Drag songs to reorder your setlist for the night. StagePad remembers your order between sessions."
        ),
        TourStep(
            icon: "square.grid.2x2.fill",
            title: "Section Buttons",
            description: "Tap a section to cue Ableton to jump there at the next launch quantization point. The active section is highlighted. A queued section pulses while Ableton counts in."
        ),
        TourStep(
            icon: "playpause.fill",
            title: "Transport Bar",
            description: "PLAY and STOP control Ableton's transport directly from the iPad — no need to touch your computer during the service."
        ),
    ]

    private var totalPages: Int { tourSteps.count + 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip Tour") { isPresented = false }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            }

            TabView(selection: $page) {
                aboutPage.tag(0)
                ForEach(Array(tourSteps.enumerated()), id: \.offset) { index, step in
                    tourPage(step: step).tag(index + 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            bottomBar
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var aboutPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.tint)
                    Text("Demo Mode")
                        .font(.largeTitle.bold())
                    Text("The Bridge app wasn't found on your network.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label("What is the Bridge app?", systemImage: "desktopcomputer")
                        .font(.headline)
                    Text("StagePad is a live performance controller for **Ableton Live**. The StagePad Bridge is a companion Mac app that runs alongside Ableton and links the two over your local network — via Wi-Fi or USB. No IP address setup required.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Right now", systemImage: "eye")
                        .font(.headline)
                    Text("You're exploring a demo with sample songs so you can see what StagePad looks and feels like. Swipe through the tour on the next pages to learn what each part of the interface does.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Going live", systemImage: "bolt.fill")
                        .font(.headline)
                    Text("Install the StagePad Bridge on your Mac, open Ableton with a session, and StagePad will connect automatically the next time you launch.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
        }
    }

    private func tourPage(step: TourStep) -> some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: step.icon)
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            VStack(spacing: 14) {
                Text(step.title)
                    .font(.title.bold())
                Text(step.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 48)
            Spacer()
            Spacer()
        }
    }

    private var bottomBar: some View {
        HStack {
            HStack(spacing: 7) {
                ForEach(0..<totalPages, id: \.self) { i in
                    Circle()
                        .fill(page == i ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 7, height: 7)
                        .animation(.easeInOut(duration: 0.2), value: page)
                }
            }
            Spacer()
            if page < totalPages - 1 {
                Button("Next") {
                    withAnimation { page += 1 }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Get Started") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
}
