import Cocoa
import SwiftUI

class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem
    private var audioRecorder: AudioRecorder
    private var transcriptionService: TranscriptionService
    private var keyboardShortcutManager: KeyboardShortcutManager
    private var textInputService: TextInputService
    private var settingsWindow: NSWindow?

    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var lastTranscription = ""
    
    init() {
        Logger.shared.info("Initializing StatusBarController")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        Logger.shared.info("Status item created")
        
        audioRecorder = AudioRecorder()
        Logger.shared.info("Audio recorder created")
        
        transcriptionService = TranscriptionService()
        Logger.shared.info("Transcription service created")
        
        keyboardShortcutManager = KeyboardShortcutManager()
        Logger.shared.info("Keyboard shortcut manager created")
        
        textInputService = TextInputService()
        Logger.shared.info("Text input service created")
        
        setupStatusItem()
        setupKeyboardShortcuts()
        setupObservers()
        Logger.shared.info("StatusBarController initialization complete")
    }
    
    private func setupStatusItem() {
        Logger.shared.info("Setting up status item")
        if let statusButton = statusItem.button {
            statusButton.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Voice Transcriber")
            // Remove click action since we're using menu
            // statusButton.action = #selector(statusItemClicked)
            // statusButton.target = self
            Logger.shared.info("Status button configured with mic icon")
        } else {
            Logger.shared.error("Failed to get status button")
        }
        
        updateStatusItemAppearance()
        setupMenu()
        Logger.shared.info("Status item setup complete")
    }
    
    private func setupMenu() {
        updateMenu()
    }
    
    private func updateMenu() {
        let menu = NSMenu()
        
        let recordingItem = NSMenuItem(
            title: isRecording ? "Stop Recording" : "Start Recording", 
            action: #selector(toggleRecording), 
            keyEquivalent: ""
        )
        recordingItem.target = self
        recordingItem.isEnabled = !isProcessing
        menu.addItem(recordingItem)
        
        if isProcessing {
            let processingItem = NSMenuItem(title: "Processing...", action: nil, keyEquivalent: "")
            processingItem.isEnabled = false
            menu.addItem(processingItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Voice Transcriber", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        Logger.shared.info("Menu updated - recording: \(isRecording), processing: \(isProcessing)")
    }
    
    private func setupKeyboardShortcuts() {
        Logger.shared.info("Setting up keyboard shortcuts")
        keyboardShortcutManager.onShortcutPressed = { [weak self] in
            Logger.shared.info("Keyboard shortcut pressed - toggling recording")
            DispatchQueue.main.async {
                self?.toggleRecording()
            }
        }
        Logger.shared.info("Keyboard shortcuts setup complete")
    }
    
    private func setupObservers() {
        audioRecorder.onRecordingStateChanged = { [weak self] isRecording in
            DispatchQueue.main.async {
                self?.isRecording = isRecording
                self?.updateStatusItemAppearance()
                self?.updateMenu()
            }
        }
        
        transcriptionService.onTranscriptionComplete = { [weak self] result in
            Logger.shared.info("Transcription completed with result: \(result)")
            DispatchQueue.main.async {
                self?.isProcessing = false
                self?.updateStatusItemAppearance()
                self?.updateMenu()
                
                if let text = result["text"] as? String, !text.isEmpty {
                    Logger.shared.info("Transcribed text: '\(text)'")
                    self?.lastTranscription = text
                    Logger.shared.info("Inserting text into active application")
                    self?.textInputService.insertText(text)
                } else {
                    Logger.shared.warn("No text found in transcription result or text is empty")
                }
            }
        }
    }
    
    private func updateStatusItemAppearance() {
        guard let statusButton = statusItem.button else { return }
        
        if isProcessing {
            statusButton.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Processing")
        } else if isRecording {
            statusButton.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
        } else {
            statusButton.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Voice Transcriber")
        }
    }
    
    @objc private func statusItemClicked() {
        Logger.shared.info("=== STATUS ITEM CLICKED ===")
        toggleRecording()
    }
    
    @objc private func toggleRecording() {
        Logger.shared.info("Toggle recording called - current state: recording=\(isRecording), processing=\(isProcessing)")
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        Logger.shared.info("Start recording requested")
        guard !isRecording && !isProcessing else { 
            Logger.shared.warn("Cannot start recording - already recording=\(isRecording) or processing=\(isProcessing)")
            return 
        }
        Logger.shared.info("Starting audio recording")
        audioRecorder.startRecording()
    }
    
    private func stopRecording() {
        Logger.shared.info("Stop recording requested")
        guard isRecording else { 
            Logger.shared.warn("Cannot stop recording - not currently recording")
            return 
        }
        
        Logger.shared.info("Stopping audio recording")
        if let audioPath = audioRecorder.stopRecording() {
            Logger.shared.info("Audio recorded to: \(audioPath)")
            isProcessing = true
            updateStatusItemAppearance()
            updateMenu()
            Logger.shared.info("Starting transcription process")
            transcriptionService.transcribe(audioPath: audioPath)
        } else {
            Logger.shared.error("Failed to get audio path from recorder")
        }
    }
    
    @objc private func openSettings() {
        // If window already exists, just bring it to front
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create the settings window
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false

        // Store reference to window
        settingsWindow = window

        // Show the window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        Logger.shared.info("Settings window opened")
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
    
    func cleanup() {
        audioRecorder.cleanup()
        transcriptionService.cleanup()
        keyboardShortcutManager.cleanup()
    }
}