import SwiftUI

struct DetailView: View {
    let pokemon: PokemonSummary

    var body: some View {
        List {
            Section("Pokémon") {
                Text(pokemon.name)
                    .font(.title2.bold())
            }

            Section("Abilities") {
                if pokemon.abilities.isEmpty {
                    Text("No abilities found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pokemon.abilities) { ability in
                        Text(ability.name)
                    }
                }
            }
        }
        .navigationTitle("Details")
    }
}

