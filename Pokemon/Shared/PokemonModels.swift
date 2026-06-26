import Foundation

struct PokemonSearchPage: Equatable, Sendable {
    let results: [PokemonSpeciesSearchResult]
    let limit: Int
    let offset: Int

    var hasMore: Bool {
        results.count == limit
    }
}

struct PokemonSpeciesSearchResult: Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let captureRate: Int
    let colorName: String
    let pokemons: [PokemonSummary]
}

struct PokemonSummary: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let abilities: [PokemonAbility]
}

struct PokemonAbility: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}
