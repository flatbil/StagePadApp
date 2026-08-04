import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var bridge: BridgeService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("orgLogoData") private var orgLogoData: Data = Data()
    @State private var logoPickerItem: PhotosPickerItem?
    @State private var hostInput: String = ""

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
