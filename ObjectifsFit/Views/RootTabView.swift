import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Accueil", systemImage: "house") }

            ProgramBuilderView()
                .tabItem { Label("Programme", systemImage: "calendar") }

            DashboardView()
                .tabItem { Label("Tableau de bord", systemImage: "chart.bar") }

            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape") }
        }
    }
}
