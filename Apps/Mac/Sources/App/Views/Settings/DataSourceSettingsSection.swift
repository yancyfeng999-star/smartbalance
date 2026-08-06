import SwiftUI
import Domain

struct DataSourceSettingsSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsChrome.card(title: "数据源（怎么知道余额）") {
            Toggle(isOn: Binding(
                get: { model.settings.apiQueryEnabled },
                set: { model.apiQueryOn = $0 }
            )) {
                SettingsChrome.labelStack(DataSourceKind.api.titleCN, DataSourceKind.api.subtitleCN)
            }
            .toggleStyle(.switch)

            Toggle(isOn: Binding(
                get: { model.settings.platformMailEnabled },
                set: { model.platformMailOn = $0 }
            )) {
                SettingsChrome.labelStack(
                    DataSourceKind.platformEmail.titleCN,
                    DataSourceKind.platformEmail.subtitleCN
                )
            }
            .toggleStyle(.switch)
        }
    }
}
