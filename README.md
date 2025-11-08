# Voice Transcriber for macOS

A real-time voice transcription app for macOS that uses Apple's MLX framework and the Parakeet model to convert speech to text with high accuracy. Features global keyboard shortcuts and automatic text insertion.

## Features

- 🎤 **Real-time Voice Transcription** using MLX and Parakeet-TDT-0.6b-v2
- 🤖 **AI Text Cleanup** - Local LLM post-processing to fix transcription errors and improve formatting
- ⌨️ **Global Keyboard Shortcuts** (Ctrl+Alt+Cmd+Shift + any key)
- 📝 **Universal Text Insertion** works in all applications (Terminal, Emacs, Chrome, etc.)
- 🔄 **Menu Bar Integration** with visual recording status
- 🐍 **Automatic Python Setup** - no manual configuration required
- 🎯 **Smart Text Insertion** using clipboard and accessibility APIs
- ⚡ **Fast and Local** - all processing happens on-device
- 🎨 **Multiple Cleanup Styles** - General, Coding, Punctuation, and custom prompts

## Requirements

- **macOS 11.0+** (Big Sur or later)
- **Apple Silicon Mac** (M1/M2/M3) - required for MLX framework
- **FFmpeg** (automatically handled via Homebrew paths)
- **Accessibility permissions** for text insertion and keyboard shortcuts

## Installation

### Build from Source
1. Clone this repository:
   ```bash
   git clone https://github.com/ketanagrawal/voice-transcriber-macos.git
   cd voice-transcriber-macos
   ```

2. Install FFmpeg (if not already installed):
   ```bash
   brew install ffmpeg
   ```

3. Install uv (Python package manager):
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

4. Build the app:
   ```bash
   ./build.sh
   ```

5. Run the built app:
   ```bash
   open VoiceTranscriber.app
   ```

## Setup

### First Launch
The app will automatically:
1. Create a Python 3.10 virtual environment
2. Install parakeet-mlx, mlx-lm, and dependencies
3. Download the Parakeet transcription model (~150MB)
4. Download the Qwen2.5 text cleanup model (~400MB) on first use

This process takes 1-2 minutes on first launch. The text cleanup model downloads automatically when you first use the cleanup feature.

### Permissions Required
The app needs two types of permissions:

#### 1. Accessibility Permissions
For text insertion and keyboard shortcuts:
1. Go to **System Settings** → **Privacy & Security** → **Accessibility**
2. Click the **+** button and add `VoiceTranscriber.app`
3. Ensure it's checked/enabled

#### 2. Input Monitoring (Optional)
For global keyboard shortcuts:
1. Go to **System Settings** → **Privacy & Security** → **Input Monitoring**  
2. Add `VoiceTranscriber.app` if prompted

## Usage

### Recording Options
**Menu Bar:** Click the microphone icon → "Start Recording"
**Keyboard Shortcut:** Hold `Ctrl+Alt+Cmd+Shift` + press any key

### Recording Process
1. **Start Recording** - Icon turns orange, menu shows "Stop Recording"
2. **Speak** - Talk clearly into your microphone
3. **Stop Recording** - Click menu item or use keyboard shortcut again
4. **Transcription** - Text automatically appears where your cursor is

### Supported Applications
The transcriber works in all text input fields:
- **Terminals** (Terminal.app, iTerm2, etc.)
- **Text Editors** (Emacs, VS Code, Sublime Text, etc.)
- **Web Browsers** (Chrome, Safari, Firefox)
- **Chat Apps** (Slack, Discord, Messages)
- **Documents** (Word, Pages, Google Docs)
- **Code Editors** (Xcode, Cursor, etc.)

## How It Works

1. **Audio Capture** - Records high-quality audio using AVFoundation
2. **ML Transcription** - Uses Apple's MLX framework with Parakeet-TDT-0.6b-v2 model
3. **AI Text Cleanup** (Optional) - Post-processes transcription using a local LLM (Qwen2.5-0.5B-Instruct)
4. **Text Insertion** - Smart insertion via clipboard (Cmd+V) with fallback to key events
5. **Cross-App Compatible** - Works universally across all macOS applications

### AI Text Cleanup

The app includes an optional AI-powered text cleanup feature that post-processes transcribed text to:
- Fix transcription errors and formatting issues
- Convert spoken file references (e.g., "main dot py" → "@main.py" in coding mode)
- Add proper punctuation and capitalization
- Format code variable names correctly

**Cleanup Styles:**
- **General** - Fixes formatting errors and improves readability
- **Coding** - Formats code references and technical terminology (e.g., "@file.py", "getUserById")
- **Punctuation** - Adds proper punctuation while keeping words exactly as transcribed

The cleanup uses Qwen2.5-0.5B-Instruct-4bit, an extremely small (300-400MB) and fast quantized model that runs locally on your Mac with minimal performance impact.

## Project Structure

```
voice-transcriber/
├── VoiceTranscriber/           # Swift application source
│   ├── VoiceTranscriberApp.swift
│   ├── StatusBarController.swift
│   ├── AudioRecorder.swift
│   ├── TranscriptionService.swift
│   ├── TextInputService.swift
│   ├── KeyboardShortcutManager.swift
│   ├── SettingsView.swift
│   └── Logger.swift
├── python/                     # Python transcription server
│   ├── transcription_server.py
│   └── text_cleanup.py         # LLM text cleanup module
├── requirements.txt            # Python dependencies
├── .voice_transcriber_prompts.example.json  # Example custom prompts
├── build.sh                   # Build script
└── README.md
```

## Configuration

### Keyboard Shortcut
The default shortcut is `Ctrl+Alt+Cmd+Shift + any key`. This is intentionally a complex combination to avoid conflicts with other applications.

### Transcription Model
The app uses `mlx-community/parakeet-tdt-0.6b-v2` for transcription. This model provides excellent accuracy for English speech and runs efficiently on Apple Silicon.

### AI Text Cleanup Settings
Access settings via the menu bar icon → Settings:
- **Enable/Disable Cleanup** - Toggle the LLM text cleanup feature
- **Cleanup Style** - Choose between General, Coding, or Punctuation modes
- **Custom Prompts** - Add your own cleanup styles (see below)

### Custom Cleanup Prompts
You can create custom cleanup prompts for specific use cases:

1. Copy the example config:
   ```bash
   cp .voice_transcriber_prompts.example.json ~/.voice_transcriber_prompts.json
   ```

2. Edit `~/.voice_transcriber_prompts.json` to add your custom prompts:
   ```json
   {
     "medical": "Your custom prompt for medical transcription...",
     "legal": "Your custom prompt for legal transcription...",
     "email": "Your custom prompt for email formatting..."
   }
   ```

3. Restart the app to load custom prompts

Custom prompts will appear in the Settings dropdown alongside the built-in options.

## Troubleshooting

### "Accessibility permissions not granted"
- Go to System Settings → Privacy & Security → Accessibility
- Add VoiceTranscriber.app and ensure it's enabled
- Restart the app after granting permissions

### "Python environment setup failed"
- Ensure you have internet connection for downloading dependencies
- Check that uv is installed: `which uv`
- Try deleting `.venv` folder and restarting the app

### "FFmpeg not found"
- Install FFmpeg: `brew install ffmpeg`
- Restart the app

### Text not inserting
- Grant Accessibility permissions
- Try using the menu bar option instead of keyboard shortcut
- Check that you're focused on a text input field

### Poor transcription quality
- Speak clearly and at moderate pace
- Ensure good microphone quality
- Record in a quiet environment
- Keep recordings under 30 seconds for best results
- Try enabling AI text cleanup in Settings for better formatting

### Text cleanup not working
- Check that mlx-lm is installed in the Python environment
- First cleanup may take longer as the model downloads (~400MB)
- Check `/tmp/voice_transcriber.log` for errors
- Try disabling cleanup if you prefer raw transcription

## Development

### Building
```bash
# Install dependencies
brew install ffmpeg
curl -LsSf https://astral.sh/uv/install.sh | sh

# Build
swiftc -o VoiceTranscriber VoiceTranscriber/*.swift \
    -framework Cocoa -framework SwiftUI \
    -framework AVFoundation -framework Carbon

# Create app bundle
mkdir -p VoiceTranscriber.app/Contents/MacOS
cp VoiceTranscriber VoiceTranscriber.app/Contents/MacOS/
```

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Apple MLX** - Machine learning framework for Apple Silicon
- **Parakeet-MLX** - Speech recognition model implementation
- **MLX-LM** - LLM inference library for Apple Silicon
- **Qwen2.5** - Efficient small language model by Alibaba Cloud
- **Hugging Face** - Model hosting and community

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Search [existing issues](https://github.com/ketanagrawal/voice-transcriber-macos/issues)
3. Create a new issue with:
   - macOS version
   - Mac model (M1/M2/M3)
   - Error logs from Console.app (search for "voice_transcriber")
   - Steps to reproduce

---

Built with ❤️ for the macOS community