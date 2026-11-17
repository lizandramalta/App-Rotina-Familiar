import SwiftUI

/// Private enlarged view of a Kids signal photo (UX-013 §5.2/§8). The image lives only in memory: there is no
/// share, save or export action. Pinch to zoom, double-tap toggles 1× ↔ 2.5×.
struct KidsPrivatePhotoViewer: View {
    let image: UIImage
    /// "<tarefa> · <criança> · <data e hora>" shown over the dark background (Figma 870:27317).
    var caption: String = ""
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1

    static let zoomedScale: CGFloat = 2.5
    static let scaleRange: ClosedRange<CGFloat> = 1 ... 4

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.App.System.dimming.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            scale = Self.clamped(committedScale * value.magnification)
                        }
                        .onEnded { _ in committedScale = scale }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.snappy) {
                        scale = Self.toggledScale(from: scale)
                        committedScale = scale
                    }
                }
                .accessibilityLabel("kidsReview.detail.photo")
                .accessibilityAddTraits(.isImage)
                .accessibilityIdentifier("kidsReview.photo.viewer")

            if !caption.isEmpty {
                Text(caption)
                    .font(.app(.note))
                    .foregroundStyle(Color.App.Text.onAction)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xxl)
                    .padding(.bottom, AppSpacing.xxl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("kidsReview.photo.caption")
            }

            Button { dismiss() } label: {
                FamilyCircleIconLabel(systemImage: "xmark")
            }
            .buttonStyle(.plain)
            .padding(AppSpacing.lg)
            .accessibilityLabel("kidsReview.photo.close")
            .accessibilityIdentifier("kidsReview.photo.close")
        }
        .presentationDetents([.large])
        .presentationBackground(Color.App.System.dimming)
    }

    static func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, scaleRange.lowerBound), scaleRange.upperBound)
    }

    static func toggledScale(from current: CGFloat) -> CGFloat {
        current > 1 ? 1 : zoomedScale
    }
}
