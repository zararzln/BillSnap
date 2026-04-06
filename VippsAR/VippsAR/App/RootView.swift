import SwiftUI

struct RootView: View {
    @State private var container = AppContainer()

    var body: some View {
        TabView(selection: Bindable(container).tab) {
            ARSplitEntryView()
                .tabItem { Label("Split", systemImage: "camera.viewfinder") }
                .tag(AppContainer.Tab.split)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
                .tag(AppContainer.Tab.history)
        }
        .environment(container)
    }
}
