import SwiftUI

@main
struct UniScheduleApp: App {
    @AppStorage(Constants.prefThemeMode) private var savedTheme = ThemeMode.system.rawValue
    
    private var colorScheme: ColorScheme? {
        ThemeMode(rawValue: savedTheme)?.colorScheme
    }
    
    var body: some Scene {
        WindowGroup {
            MainScheduleView()
                .preferredColorScheme(colorScheme)
        }
    }
}
