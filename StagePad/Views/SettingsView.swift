import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var bridge: BridgeService
    @Environment(\.dismiss) private var dismiss
    @State private var hostInput: String = ""
    @State private var cueTrackName: String = "Cues"
    @State private var cueGenerating: Bool = false
    @State private var cueGenerateDone: Bool = false
    @State private var guideTrackName: String = "Guide"

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {

                // Connection info
                VStack(alignment: .leading, spacing: 0) {
                    Text("Auto-Discovery")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(.secondary)
                            Text("The app finds the bridge automatically via Bonjour. When the iPad is connected via USB-C, it uses that connection instead of Wi-Fi.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }

                // Manual fallback
                VStack(alignment: .leading, spacing: 0) {
                    Text("Manual Fallback IP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        TextField("Mac IP Address (e.g. 10.0.0.101)", text: $hostInput)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                            .padding()

                        Divider()

                        Text("Used only if Bonjour discovery times out (3 s). Find the Mac's IP in System Settings → Network.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }

                // Cue generation
                VStack(alignment: .leading, spacing: 0) {
                    Text("Auto-Generate Markers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        HStack {
                            Text("Cues track name")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                            Spacer()
                            TextField("Cues", text: $cueTrackName)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .frame(width: 120)
                        }
                        .padding()

                        Divider()

                        Text("Scans the named Ableton track for arrangement clips and creates cue markers from their names and positions. Name clips \u{201C}== Song Name ==\u{201D} for song headers or \u{201C}Chorus\u{201D}, \u{201C}Verse 1\u{201D} etc. for sections.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()

                        Button(action: {
                            cueGenerating = true
                            cueGenerateDone = false
                            bridge.generateCues(trackName: cueTrackName.isEmpty ? "Cues" : cueTrackName)
                            // The bridge takes ~1s to process — show feedback then clear
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                cueGenerating = false
                                cueGenerateDone = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                                cueGenerateDone = false
                            }
                        }) {
                            HStack(spacing: 8) {
                                if cueGenerating {
                                    ProgressView().tint(.purple)
                                } else if cueGenerateDone {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                }
                                Text(cueGenerateDone ? "Markers generated" : "Generate from \(cueTrackName.isEmpty ? "Cues" : cueTrackName)")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .disabled(cueGenerating || bridge.connectionState != .connected)
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }

                // Guide track analysis
                VStack(alignment: .leading, spacing: 0) {
                    Text("Auto-Generate from Guide Track")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        HStack {
                            Text("Guide track name")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                            Spacer()
                            TextField("Guide", text: $guideTrackName)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .frame(width: 120)
                        }
                        .padding()

                        Divider()

                        Text("Analyzes the audio on the named Ableton track using AI speech recognition. Detects the BPM from the click, reads spoken section cues (\"Verse 1\", \"Chorus\", etc.), and creates all markers automatically. First run downloads the Whisper model (~74 MB).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()

                        Button(action: {
                            bridge.analyzeGuide(trackName: guideTrackName.isEmpty ? "Guide" : guideTrackName)
                        }) {
                            HStack(spacing: 8) {
                                switch bridge.analysisState {
                                case .running:
                                    ProgressView().tint(.purple)
                                    Text("Analyzing… (may take a minute)")
                                        .fontWeight(.semibold)
                                case .done(let bpm, let count):
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    Text("\(count) sections at \(Int(bpm)) BPM — done!")
                                        .fontWeight(.semibold)
                                case .failed:
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                    Text("Analysis failed — check bridge log")
                                        .fontWeight(.semibold)
                                case .idle:
                                    Image(systemName: "waveform.and.mic")
                                    Text("Analyze \(guideTrackName.isEmpty ? "Guide" : guideTrackName) Track")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .disabled(bridge.analysisState == .running || bridge.connectionState != .connected)
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }

                // Reconnect button
                Button(action: {
                    bridge.host = hostInput
                    bridge.connect()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                        Text("Reconnect to Bridge")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        bridge.host = hostInput
                        bridge.connect()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { hostInput = bridge.host }
        }
    }
}
