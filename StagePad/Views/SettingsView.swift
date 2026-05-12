import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var bridge: BridgeService
    @EnvironmentObject var pc: PlanningCenterService
    @Environment(\.dismiss) private var dismiss
    @State private var hostInput: String = ""
    @State private var cueTrackName: String = "Cues"
    @State private var cueGenerating: Bool = false
    @State private var cueGenerateDone: Bool = false
    @State private var editingDevice: BridgeService.SavedDevice? = nil
    @State private var editingName: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {

                // Mode selector
                VStack(alignment: .leading, spacing: 10) {
                    Text("APP MODE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        modeButton(
                            title: "Bridge Mode",
                            subtitle: "Connect to Ableton",
                            icon: "cable.connector",
                            mode: .bridge,
                            color: .green
                        )
                        modeButton(
                            title: "Arrangement Sheet",
                            subtitle: "Offline / PC charts",
                            icon: "music.note.list",
                            mode: .arrangementSheet,
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                }

                // Saved devices
                if !bridge.savedDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Saved Bridges")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Swipe to remove")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 6)

                        VStack(spacing: 0) {
                            ForEach(bridge.savedDevices) { device in
                            Button(action: {
                                bridge.connect(to: device)
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.name)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.primary)
                                        Text(device.host)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if bridge.connectionState == .connected,
                                       bridge.activeHostPublished == device.host {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    }
                                }
                                .padding()
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingDevice = device
                                    editingName = device.name
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    bridge.deleteDevice(device)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }

                            if device.id != bridge.savedDevices.last?.id {
                                Divider().padding(.leading)
                            }
                        }
                        }
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
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
                    Text("Manual IP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        TextField("Mac IP Address (e.g. 192.168.4.29)", text: $hostInput)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                            .padding()

                        Divider()

                        Text("Used if Bonjour discovery times out (3 s). Find the Mac's IP in System Settings → Network.")
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
                        Text("Connect to Bridge")
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
            .alert("Rename Bridge", isPresented: Binding(
                get: { editingDevice != nil },
                set: { if !$0 { editingDevice = nil } }
            )) {
                TextField("Name", text: $editingName)
                    .autocorrectionDisabled()
                Button("Save") {
                    if let device = editingDevice, !editingName.isEmpty {
                        bridge.renameDevice(device, to: editingName)
                    }
                    editingDevice = nil
                }
                Button("Cancel", role: .cancel) { editingDevice = nil }
            } message: {
                Text(editingDevice?.host ?? "")
            }
        }
    }

    @ViewBuilder
    private func modeButton(title: String, subtitle: String, icon: String, mode: AppMode, color: Color) -> some View {
        let isActive = pc.appMode == mode
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                pc.appMode = mode
            }
            if mode == .arrangementSheet {
                Task { await pc.fetchCurrentPlan() }
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isActive ? color : .white.opacity(0.4))
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.5))
                Text(subtitle)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(isActive ? color.opacity(0.8) : .white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isActive ? color.opacity(0.15) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isActive ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
