import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        if hasSeenWelcome {
            HomeView()
        } else {
            WelcomeView {
                hasSeenWelcome = true
            }
        }
    }
}

private struct WelcomeView: View {
    private enum Constants {
        static let stackSpacing: CGFloat = 24
        static let iconSize: CGFloat = 56
        static let textStackSpacing: CGFloat = 8
    }

    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Constants.stackSpacing) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: Constants.iconSize))
                .foregroundStyle(.blue)

            VStack(spacing: Constants.textStackSpacing) {
                Text("Welcome to Pokémon Quiz Demo")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text("Search Pokémon species and inspect each Pokémon's abilities.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Continue") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }
}

