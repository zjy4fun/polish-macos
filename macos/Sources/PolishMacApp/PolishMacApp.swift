import SwiftUI

@main
struct PolishMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(viewModel: appDelegate.viewModel)
                .frame(width: 520, height: 360)
        }
    }
}
