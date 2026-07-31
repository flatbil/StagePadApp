import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var bridge: BridgeService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("orgLogoData") private var orgLogoData: Data = Data()
    @State private var logoPickerItem: PhotosPickerItem?
    @State private var hostInput: String = ""
    @State private var cueTrackName: String = "Cues"
    @State private var cueGenerating: Bool = false
    @State private var cueGenerateDone: Bool = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {

                // Organization logo
                VStack(alignment: .leading, spacing: 0) {
                    Text("Organization Logo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 6)

                    HStack(spacing: 16) {
                        if let ui = UIImage(data: orgLogoData), !orgLogoData.isEmpty {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            PhotosPicker(selection: $logoPickerItem, matching: .images) {
                                Text(orgLogoData.isEmpty ? "Choose Logo…" : "Change Logo")
                                    .font(.footnote.weight(.medium))
                            }
                            if !orgLogoData.isEmpty {
                                Button("Remove") { orgLogoData = Data() }
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }
                .onChange(of: logoPickerItem) { _, item in
                    Task {
                        if let data = try? await item?.loadTransferable(type: Data.self) {
                            orgLogoData = data
                        }
                    }
                }

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

                // Demo mode — explore with sample songs without a bridge.
                Button(action: {
                    bridge.enterDemoMode()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "play.rectangle.fill")
                        Text("Enter Demo Mode")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
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
