import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("排班", systemImage: "calendar") }
            NavigationStack {
                RosterListView()
            }
            .tabItem { Label("明细", systemImage: "list.bullet.rectangle") }
            TeamView()
                .tabItem { Label("团队", systemImage: "person.2") }
            TemplatesView()
                .tabItem { Label("班次", systemImage: "clock") }
        }
        .task {
            if model.result == nil {
                model.solve()
            }
        }
    }
}
