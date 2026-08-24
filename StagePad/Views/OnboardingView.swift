import SwiftUI

private struct OnboardingPage {
    let systemImage: String
    let tint: Color
    let title: String
    let body: String
    var linkLabel: String? = nil
    var linkURL: String? = nil
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        systemImage: "music.note.list",
        tint: .blue,
        title: "Welcome to MD Buddy",
        body: "A live setlist controller for Ableton Live. Displays your song structure, tracks the playhead in real time, and lets you jump between sections — all from your iPad."
    ),
    OnboardingPage(
        systemImage: "arrow.down.circle.fill",
        tint: .green,
        title: "Install the Bridge",
        body: "MD Buddy requires the free MD Buddy Bridge running on the Mac connected to Ableton.\n\n1. Clone or download the repo from GitHub\n2. Open Terminal and run:  bash install.sh\n3. The bridge starts automatically at login\n\nAbletonOSC is included — no separate download needed.",
        linkLabel: "MD Buddy Bridge on GitHub",
        linkURL: "https://github.com/flatbil/AbletonTracksApp"
    ),
    OnboardingPage(
        systemImage: "waveform.and.mic",
        tint: .purple,
        title: "Connect to Ableton",
        body: "The bridge installer sets up AbletonOSC automatically — no separate download needed.\n\nAfter running install.sh, open Ableton and complete one manual step:\n\nPreferences → Link/Tempo/MIDI → Control Surface → AbletonOSC\n\nCompatible with Ableton Live 10, 11, and 12 (Standard or Suite).\nIntro and Lite editions are not supported."
    ),
    OnboardingPage(
        systemImage: "bookmark.fill",
        tint: .orange,
        title: "Name Your Markers",
        body: "MD Buddy reads Ableton's locator markers to build your setlist.\n\nNamed song header:\n    == Amazing Grace ==\n\nUnnamed song (auto-numbered):\n    Start · Inicio · Début · Anfang · Inizio\n\nSections (any name):\n    Verse 1 · Chorus · Bridge · Outro\n\nAll other markers become sections of the current song."
    ),
    OnboardingPage(
        systemImage: "checkmark.circle.fill",
        tint: .green,
        title: "You're All Set",
        body: "Open a project in Ableton, make sure the bridge is running, then tap Search for Bridge. MD Buddy finds it automatically over Wi-Fi or USB.\n\nFor detailed setup, troubleshooting, and Ableton version notes, visit the full documentation.",
        linkLabel: "Full Documentation",
        linkURL: "https://github.com/flatbil/AbletonTracksApp/wiki"
    ),
]

struct OnboardingView: View {
    var onDismiss: () -> Void
    @State private var page = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    pageView(pages[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: page)

            // Nav row sits below page dots
            HStack {
                if page > 0 {
                    Button("Back") {
                        withAnimation { page -= 1 }
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Spacer().frame(width: 60)
                }

                Spacer()

                if page < pages.count - 1 {
                    Button("Skip") { onDismiss() }
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 16)
                    Button("Next") {
                        withAnimation { page += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") { onDismiss() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .preferredColorScheme(.dark)
    }

    private func pageView(_ p: OnboardingPage) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 40)

                Image(systemName: p.systemImage)
                    .font(.system(size: 72))
                    .foregroundStyle(p.tint)
                    .shadow(color: p.tint.opacity(0.4), radius: 20)

                Text(p.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                Text(p.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)

                if let label = p.linkLabel, let urlStr = p.linkURL, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                            Text(label)
                                .fontWeight(.medium)
                        }
                        .font(.footnote)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(p.tint.opacity(0.15))
                        .foregroundStyle(p.tint)
                        .clipShape(Capsule())
                    }
                }

                Spacer().frame(height: 80) // clearance for nav row + page dots
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
    }
}
