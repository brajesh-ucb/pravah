import SwiftUI

struct ImagePreviewView: View {
    let image: UIImage

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .overlay(alignment: .topTrailing) {
                Button("Close", systemImage: "xmark.circle.fill") { dismiss() }
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding()
            }
    }
}

#Preview {
    ImagePreviewView(image: UIImage(systemName: "photo") ?? UIImage())
}
