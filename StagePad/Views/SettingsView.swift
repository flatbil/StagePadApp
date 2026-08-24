import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var bridge: BridgeService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("orgLogoData") private var orgLogoData: Data = Data()
    @State private var logoPickerItem: PhotosPickerItem?
    @State private var hostInput: String = ""
    @State private var newHostName: String = ""
    @State private var showingHelp = false

    var body: some View {
        NavigationStack {
            ScrollView {
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

                        if !bridge.connectionDetail.isEmpty {
                            Divider()
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.blue)
                                Text(bridge.connectionDetail)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.primary)
                            }
                            .padding()
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }

                // Trusted connections — saved, named IPs the user can pick with one tap.
                VStack(alignment: .leading, spacing: 0) {
                    Text("Trusted Connections")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        if bridge.trustedHosts.isEmpty {
                            Text("No saved connections yet. Add one below for a one-tap reconnect instead of retyping an IP.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(Array(bridge.trustedHosts.enumerated()), id: \.element.id) { index, entry in
                                if index > 0 { Divider() }
                                HStack(spacing: 12) {
                                    Button {
                                        bridge.selectTrustedHost(entry)
                                        dismiss()
                                    } label: {
                                        HStack {
                                            Image(systemName: bridge.host == entry.ipAddress ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(bridge.host == entry.ipAddress ? .green : .secondary)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(entry.name)
                                                    .foregroundStyle(.primary)
                                                Text(entry.ipAddress)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        if let idx = bridge.trustedHosts.firstIndex(where: { $0.id == entry.id }) {
                                            bridge.removeTrustedHost(at: IndexSet(integer: idx))
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding()
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }

                // Add a connection — saves as trusted, or just reconnects once.
                VStack(alignment: .leading, spacing: 0) {
                    Text("Add a Connection")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        TextField("Name (e.g. Church Tracks Computer)", text: $newHostName)
                            .autocorrectionDisabled()
                            .padding()

                        Divider()

                        TextField("Mac IP Address (e.g. 10.0.0.101)", text: $hostInput)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                            .padding()

                        Divider()

                        Button {
                            bridge.addTrustedHost(name: newHostName, ipAddress: hostInput)
                            newHostName = ""
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Save as Trusted Connection")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .disabled(hostInput.trimmingCharacters(in: .whitespaces).isEmpty)

                        Divider()

                        Text("A saved IP is only used as a fallback if Bonjour discovery times out (3 s). Find the Mac's IP in System Settings → Network.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
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

                // Help & Setup
                VStack(alignment: .leading, spacing: 0) {
                    Text("Help & Setup")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        Button {
                            showingHelp = true
                        } label: {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                Text("Setup Guide")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                                    .font(.caption)
                            }
                            .foregroundStyle(.primary)
                            .padding()
                        }

                        Divider()

                        if let url = URL(string: "https://github.com/flatbil/AbletonTracksApp/wiki") {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "book")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    Text("Full Documentation")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.tertiary)
                                        .font(.caption)
                                }
                                .foregroundStyle(.primary)
                                .padding()
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }
                .sheet(isPresented: $showingHelp) {
                    OnboardingView { showingHelp = false }
                }

            }
            .padding(.top)
            } // ScrollView
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
