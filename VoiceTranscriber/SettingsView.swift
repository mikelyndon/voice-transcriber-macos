import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedModel") private var selectedModel = "mlx-community/parakeet-tdt-0.6b-v2"
    @AppStorage("shortcutKey") private var shortcutKey = "fn"
    
    private let availableModels = [
        "mlx-community/parakeet-tdt-0.6b-v2",
        "mlx-community/parakeet-tdt-1.1b-v2"
    ]
    
    private let availableShortcuts = [
        "fn": "Fn Key",
        "f13": "F13",
        "f14": "F14",
        "f15": "F15"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Voice Transcriber Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Transcription Model")
                    .font(.headline)
                
                Picker("Model", selection: $selectedModel) {
                    ForEach(availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Text("Choose the Parakeet model for transcription. Larger models may be more accurate but slower.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Keyboard Shortcut")
                    .font(.headline)
                
                Picker("Shortcut Key", selection: $shortcutKey) {
                    ForEach(availableShortcuts.keys.sorted(), id: \.self) { key in
                        Text(availableShortcuts[key] ?? key).tag(key)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Text("Press this key to start/stop recording. Make sure to grant accessibility permissions.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Permissions")
                    .font(.headline)
                
                PermissionRow(
                    title: "Microphone Access",
                    description: "Required to record audio for transcription",
                    systemImage: "mic.fill"
                )
                
                PermissionRow(
                    title: "Accessibility Access", 
                    description: "Required to insert transcribed text into other apps",
                    systemImage: "accessibility"
                )
            }
            
            Spacer()
            
            HStack {
                Spacer()
                
                Button("Open Privacy Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 500, height: 400)
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let systemImage: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}