import SunriseKit
import SunriseUI
import SwiftUI

/// Pick a city, or the watch's location.
struct WatchCitiesView: View {
    @Environment(SunStore.self) private var store
    @Environment(LocationProvider.self) private var location

    var body: some View {
        List {
            Section {
                Button {
                    location.request()
                } label: {
                    Label(location.isLocating ? "Locating…" : "Use My Location", systemImage: "location.fill")
                }
                if let message = location.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Cities") {
                ForEach(City.all) { city in
                    Button {
                        store.selected = city
                    } label: {
                        HStack {
                            Text(city.name)
                            Spacer()
                            if city == store.selected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(SunPalette.golden)
                            }
                        }
                    }
                }
            }
            Section {
                Text(SunriseSunsetAttribution.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: location.city) { _, city in
            if let city {
                store.selected = city
            }
        }
    }
}
