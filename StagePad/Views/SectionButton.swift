import SwiftUI

struct SectionButton: View {
    let label: String
    let color: Color
    let icon: String
    let isActive: Bool
    let progress: Double   // 0.0–1.0, only meaningful when isActive
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Base fill
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isActive ? color : color.opacity(0.45))

                    // Progress fill — semi-transparent so text/icon remain readable
                    if isActive && progress > 0 {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.12))
                            .frame(width: geo.size.width * min(progress, 1.0))
                            .animation(.linear(duration: 0.3), value: progress)
                    }

                    // Watermark icon
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(0.08))
                        .padding(12)
                        .frame(width: geo.size.width, height: geo.size.height)

                    // Active glow border
                    if isActive {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.8), lineWidth: 3)
                    }

                    // Label centred over everything
                    Text(label)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(10)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .buttonStyle(.plain)
        .shadow(color: isActive ? color.opacity(0.6) : .clear, radius: 10)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}
