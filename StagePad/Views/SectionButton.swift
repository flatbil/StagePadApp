import SwiftUI

struct SectionButton: View {
    let label: String
    let color: Color
    let icon: String
    let isActive: Bool
    let progress: Double   // 0.0–1.0, only meaningful when isActive
    let danceDate: Date?   // non-nil only when active AND playing; drives icon motion
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
                    }

                    // Watermark icon — dances when danceDate is set
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(danceDate != nil ? 0.14 : 0.08))
                        .padding(12)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .modifier(DanceModifier(date: danceDate))

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

// Computes rotation/scale/offset from wall-clock time using sin/cos at two
// independent tempos so the motion feels organic. When date is nil everything
// is zero — no animation state to cancel.
private struct DanceModifier: ViewModifier {
    let date: Date?

    func body(content: Content) -> some View {
        let t = date?.timeIntervalSinceReferenceDate ?? 0
        let active = date != nil
        let rotation = active ? sin(t * .pi * 2 / 1.1) * 10.0 : 0
        let scale    = active ? 1.0 + sin(t * .pi * 2 / 1.6) * 0.12 : 1.0
        let offsetX  = active ? sin(t * .pi * 2 / 1.3) * 5.0 : 0
        let offsetY  = active ? sin(t * .pi * 2 / 1.7) * 6.0 : 0

        content
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .offset(x: offsetX, y: offsetY)
    }
}
