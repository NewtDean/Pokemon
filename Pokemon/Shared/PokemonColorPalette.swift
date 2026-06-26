import SwiftUI

enum PokemonColorPalette {
    private enum Constants {
        static let blackOpacity = 0.75
        static let lightOpacity = 0.25
        static let mediumOpacity = 0.35
        static let defaultOpacity = 0.2
    }

    static func color(for apiName: String) -> Color {
        switch apiName.lowercased() {
        case "black":
            .black.opacity(Constants.blackOpacity)
        case "blue":
            .blue.opacity(Constants.lightOpacity)
        case "brown":
            .brown.opacity(Constants.mediumOpacity)
        case "gray":
            .gray.opacity(Constants.lightOpacity)
        case "green":
            .green.opacity(Constants.lightOpacity)
        case "pink":
            .pink.opacity(Constants.mediumOpacity)
        case "purple":
            .purple.opacity(Constants.lightOpacity)
        case "red":
            .red.opacity(Constants.lightOpacity)
        case "white":
            .white
        case "yellow":
            .yellow.opacity(Constants.mediumOpacity)
        default:
            .gray.opacity(Constants.defaultOpacity)
        }
    }

    static func foregroundColor(for apiName: String) -> Color {
        apiName.lowercased() == "black" ? .white : .primary
    }
}
