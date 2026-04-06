import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var bridge: BridgeService
    @Environment(\.dismiss) private var dismiss
    @State private var hostInput: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Bridge Connection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                VStack(spacing: 0) {
                    TextField("Mac IP Address", text: $hostInput)
                        .keyboardType(.decimalPad)
                        .autocorrectionDisabled()
                        .padding()

                    Divider()

                    Text("ws://\(hostInput):8766/ws")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

                // Reconnect button
                Button(action: {
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
