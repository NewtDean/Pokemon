import SwiftUI

struct SearchLoadingWindowOverlay: View {
    private enum Constants {
        static let stackSpacing: CGFloat = 12
        static let loadingIconSize: CGFloat = 48
        static let cardCornerRadius: CGFloat = 16
        static let cardPadding: CGFloat = 24
    }

    var body: some View {
        ZStack {
            loadingCard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

    private var loadingCard: some View {
        VStack(spacing: Constants.stackSpacing) {
            Image(systemName: "hourglass.circle")
                .font(.system(size: Constants.loadingIconSize))
                .symbolEffect(.pulse)
            ProgressView("Loading Pokémon...")
        }
        .padding(Constants.cardPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Constants.cardCornerRadius))
    }
}
