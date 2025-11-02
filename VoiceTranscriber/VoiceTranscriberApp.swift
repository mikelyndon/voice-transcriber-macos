import SwiftUI

@main
struct VoiceTranscriberApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene - this is a menu bar only app
        // Settings window is managed by StatusBarController
        WindowGroup {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Voice Transcriber app started")
        Logger.shared.info("Voice Transcriber app started")
        print("Creating status bar controller")
        Logger.shared.info("Creating status bar controller")
        statusBarController = StatusBarController()
        print("Status bar controller created successfully")
        Logger.shared.info("Status bar controller created successfully")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("Voice Transcriber app terminating")
        Logger.shared.info("Voice Transcriber app terminating")
        statusBarController?.cleanup()
        print("Voice Transcriber app terminated")
        Logger.shared.info("Voice Transcriber app terminated")
    }
}