import Foundation
import OSLog

enum PokemonServiceError: Error, Equatable, LocalizedError, Sendable {
    case invalidResponse
    case httpStatus(Int)
    case graphQLErrors([String])

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The server returned an invalid response."
        case let .httpStatus(statusCode):
            "The server returned HTTP status \(statusCode)."
        case let .graphQLErrors(messages):
            messages.joined(separator: "\n")
        }
    }
}

protocol PokemonServicing: Sendable {
    func searchSpecies(name: String, limit: Int, offset: Int) async throws -> PokemonSearchPage
}

protocol GraphQLTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionGraphQLTransport: GraphQLTransport {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PokemonServiceError.invalidResponse
        }

        return (data, httpResponse)
    }
}

struct PokemonGraphQLService: PokemonServicing {
    private enum Constants {
        static let httpSuccessStatusLowerBound = 200
        static let httpSuccessStatusUpperBound = 300
    }

    private let endpoint: URL
    private let transport: GraphQLTransport
    private let logger = Logger(subsystem: "Pokemon", category: "PokemonGraphQLService")

    init(
        endpoint: URL = URL(string: "https://beta.pokeapi.co/graphql/v1beta")!,
        transport: GraphQLTransport = URLSessionGraphQLTransport()
    ) {
        self.endpoint = endpoint
        self.transport = transport
    }

    func searchSpecies(name: String, limit: Int, offset: Int) async throws -> PokemonSearchPage {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info("Searching Pokémon species, query: \(trimmedName, privacy: .public), limit: \(limit), offset: \(offset)")

        let request = try makeSearchRequest(name: trimmedName, limit: limit, offset: offset)
        let (data, response) = try await transport.data(for: request)

        guard (Constants.httpSuccessStatusLowerBound..<Constants.httpSuccessStatusUpperBound).contains(response.statusCode) else {
            logger.error("GraphQL search failed with HTTP status: \(response.statusCode)")
            throw PokemonServiceError.httpStatus(response.statusCode)
        }

        let decodedResponse = try JSONDecoder().decode(GraphQLResponse.self, from: data)

        if let errors = decodedResponse.errors, !errors.isEmpty {
            let messages = errors.map(\.message)
            logger.error("GraphQL search returned errors: \(messages.joined(separator: ", "), privacy: .public)")
            throw PokemonServiceError.graphQLErrors(messages)
        }

        let species = decodedResponse.data?.pokemonSpecies.map { dto in
            PokemonSpeciesSearchResult(
                id: dto.id,
                name: dto.name,
                captureRate: dto.captureRate,
                colorName: dto.color?.name ?? "gray",
                pokemons: dto.pokemons.map { pokemon in
                    PokemonSummary(
                        id: pokemon.id,
                        name: pokemon.name,
                        abilities: pokemon.abilities.compactMap { ability in
                            guard let name = ability.ability?.name else { return nil }
                            return PokemonAbility(id: ability.id, name: name)
                        }
                    )
                }
            )
        } ?? []

        logger.info("GraphQL search completed with \(species.count) species")
        return PokemonSearchPage(results: species, limit: limit, offset: offset)
    }

    func makeSearchRequest(name: String, limit: Int, offset: Int) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = GraphQLRequest(
            query: Self.searchQuery,
            variables: SearchVariables(
                name: "%\(name)%",
                limit: limit,
                offset: offset
            )
        )
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }
}

private extension PokemonGraphQLService {
    static let searchQuery = """
    query SearchPokemonSpecies($name: String!, $limit: Int!, $offset: Int!) {
      pokemon_v2_pokemonspecies(
        where: { name: { _ilike: $name } }
        order_by: { name: asc }
        limit: $limit
        offset: $offset
      ) {
        id
        name
        capture_rate
        pokemon_v2_pokemoncolor {
          id
          name
        }
        pokemon_v2_pokemons(order_by: { name: asc }) {
          id
          name
          pokemon_v2_pokemonabilities(order_by: { slot: asc }) {
            id
            pokemon_v2_ability {
              name
            }
          }
        }
      }
    }
    """
}

private struct GraphQLRequest: Encodable {
    let query: String
    let variables: SearchVariables
}

private struct SearchVariables: Encodable {
    let name: String
    let limit: Int
    let offset: Int
}

private struct GraphQLResponse: Decodable {
    let data: PokemonSpeciesData?
    let errors: [GraphQLError]?
}

private struct GraphQLError: Decodable {
    let message: String
}

private struct PokemonSpeciesData: Decodable {
    let pokemonSpecies: [PokemonSpeciesDTO]

    enum CodingKeys: String, CodingKey {
        case pokemonSpecies = "pokemon_v2_pokemonspecies"
    }
}

private struct PokemonSpeciesDTO: Decodable {
    let id: Int
    let name: String
    let captureRate: Int
    let color: PokemonColorDTO?
    let pokemons: [PokemonDTO]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case captureRate = "capture_rate"
        case color = "pokemon_v2_pokemoncolor"
        case pokemons = "pokemon_v2_pokemons"
    }
}

private struct PokemonColorDTO: Decodable {
    let id: Int
    let name: String
}

private struct PokemonDTO: Decodable {
    let id: Int
    let name: String
    let abilities: [PokemonAbilityJoinDTO]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case abilities = "pokemon_v2_pokemonabilities"
    }
}

private struct PokemonAbilityJoinDTO: Decodable {
    let id: Int
    let ability: PokemonAbilityDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case ability = "pokemon_v2_ability"
    }
}

private struct PokemonAbilityDTO: Decodable {
    let name: String
}
