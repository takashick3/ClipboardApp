import SwiftUI

struct ToastView: View {
    let message: String
    let systemIconName: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemIconName)
                .foregroundColor(.secondary)
                .imageScale(.small)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}
