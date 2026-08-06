import SwiftUI
import Domain

@main
struct SmartBalanceApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuRootView(model: model, runsInPinnedWindow: false)
                .onAppear {
                    PinnedBalanceWindowController.shared.bind(model: model)
                }
        } label: {
            Label {
                Text(menuBarTitle)
            } icon: {
                Image(systemName: "yensign.circle.fill")
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarTitle: String {
        if let first = model.snapshots.first(where: { $0.status != .setup && $0.status != .error }) {
            return "\(Brand.nameCN) \(first.primaryText)"
        }
        return Brand.nameCN
    }
}
