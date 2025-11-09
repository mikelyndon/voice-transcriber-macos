import Foundation

class TranscriptionService: ObservableObject {
    private var pythonProcess: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    
    var onTranscriptionComplete: (([String: Any]) -> Void)?
    
    @Published var isInitialized = false
    @Published var isProcessing = false
    
    init() {
        if ensurePythonEnvironment() {
            startPythonServer()
        } else {
            Logger.shared.error("Failed to set up Python environment")
        }
    }
    
    private func ensurePythonEnvironment() -> Bool {
        let bundlePath = Bundle.main.bundlePath
        let appContentsPath = "\(bundlePath)/Contents"
        let venvPath = "\(appContentsPath)/.venv"
        let requirementsPath = "\(appContentsPath)/requirements.txt"
        
        Logger.shared.info("Checking Python environment at: \(venvPath)")
        
        // Check if .venv exists
        if !FileManager.default.fileExists(atPath: venvPath) {
            Logger.shared.info("Python environment not found, creating with uv...")
            return setupPythonEnvironment(projectRoot: appContentsPath, venvPath: venvPath, requirementsPath: requirementsPath)
        } else {
            // Check if parakeet-mlx is installed
            let testImport = Process()
            testImport.executableURL = URL(fileURLWithPath: "\(venvPath)/bin/python")
            testImport.arguments = ["-c", "import parakeet_mlx"]
            
            do {
                try testImport.run()
                testImport.waitUntilExit()
                
                if testImport.terminationStatus != 0 {
                    Logger.shared.info("Python environment exists but parakeet-mlx not installed, installing dependencies...")
                    return installPythonDependencies(projectRoot: appContentsPath, requirementsPath: requirementsPath)
                } else {
                    Logger.shared.info("Python environment ready")
                    return true
                }
            } catch {
                Logger.shared.error("Failed to check Python environment: \(error)")
                return setupPythonEnvironment(projectRoot: appContentsPath, venvPath: venvPath, requirementsPath: requirementsPath)
            }
        }
    }
    
    private func setupPythonEnvironment(projectRoot: String, venvPath: String, requirementsPath: String) -> Bool {
        Logger.shared.info("Setting up Python environment with uv...")
        Logger.shared.info("Project root: \(projectRoot)")
        Logger.shared.info("Venv path: \(venvPath)")
        Logger.shared.info("Requirements path: \(requirementsPath)")
        
        // Create .venv with Python 3.10
        let createVenv = Process()
        let uvPath = findUvPath()
        createVenv.launchPath = uvPath
        createVenv.arguments = ["venv", "--python", "3.10", ".venv"]
        createVenv.currentDirectoryPath = projectRoot
        
        Logger.shared.info("Running command: \(uvPath) venv --python 3.10 .venv")
        Logger.shared.info("Working directory: \(projectRoot)")
        
        // Capture stdout and stderr
        let stdout = Pipe()
        let stderr = Pipe()
        createVenv.standardOutput = stdout
        createVenv.standardError = stderr
        
        do {
            try createVenv.run()
            createVenv.waitUntilExit()
            
            // Read stdout and stderr
            let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
            
            if let stdoutString = String(data: stdoutData, encoding: .utf8), !stdoutString.isEmpty {
                Logger.shared.info("uv venv stdout: \(stdoutString)")
            }
            if let stderrString = String(data: stderrData, encoding: .utf8), !stderrString.isEmpty {
                Logger.shared.info("uv venv stderr: \(stderrString)")
            }
            
            Logger.shared.info("uv venv exit code: \(createVenv.terminationStatus)")
            
            if createVenv.terminationStatus == 0 {
                Logger.shared.info("Virtual environment created successfully")
                return installPythonDependencies(projectRoot: projectRoot, requirementsPath: requirementsPath)
            } else {
                Logger.shared.error("Failed to create virtual environment, exit code: \(createVenv.terminationStatus)")
                return false
            }
        } catch {
            Logger.shared.error("Failed to run uv venv: \(error)")
            return false
        }
    }
    
    private func installPythonDependencies(projectRoot: String, requirementsPath: String) -> Bool {
        Logger.shared.info("Installing Python dependencies...")
        
        let installDeps = Process()
        installDeps.launchPath = "/bin/bash"
        let uvPath = findUvPath()
        let command = "cd \(projectRoot) && source .venv/bin/activate && \(uvPath) pip install -r requirements.txt"
        installDeps.arguments = ["-c", command]
        
        Logger.shared.info("Running pip install command: \(command)")
        
        // Capture stdout and stderr
        let stdout = Pipe()
        let stderr = Pipe()
        installDeps.standardOutput = stdout
        installDeps.standardError = stderr
        
        do {
            try installDeps.run()
            installDeps.waitUntilExit()
            
            // Read stdout and stderr
            let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
            
            if let stdoutString = String(data: stdoutData, encoding: .utf8), !stdoutString.isEmpty {
                Logger.shared.info("pip install stdout: \(stdoutString)")
            }
            if let stderrString = String(data: stderrData, encoding: .utf8), !stderrString.isEmpty {
                Logger.shared.info("pip install stderr: \(stderrString)")
            }
            
            Logger.shared.info("pip install exit code: \(installDeps.terminationStatus)")
            
            if installDeps.terminationStatus == 0 {
                Logger.shared.info("Python dependencies installed successfully")
                return true
            } else {
                Logger.shared.error("Failed to install Python dependencies, exit code: \(installDeps.terminationStatus)")
                return false
            }
        } catch {
            Logger.shared.error("Failed to run uv pip install: \(error)")
            return false
        }
    }
    
    private func findUvPath() -> String {
        // Common uv installation paths
        let uvPaths = [
            "/Users/\(NSUserName())/.local/bin/uv",  // User installation
            "/opt/homebrew/bin/uv",                  // Homebrew (Apple Silicon)
            "/usr/local/bin/uv",                     // Homebrew (Intel)
            "/usr/bin/uv"                           // System installation
        ]
        
        for path in uvPaths {
            if FileManager.default.fileExists(atPath: path) {
                Logger.shared.info("Found uv at: \(path)")
                return path
            }
        }
        
        Logger.shared.warn("uv not found in common paths, using default")
        return "uv"  // Hope it's in PATH
    }
    
    private func startPythonServer() {
        // Find the Python script path relative to the app bundle
        let bundlePath = Bundle.main.bundlePath
        
        // For development builds, go back to voice-transcriber directory
        let pythonScriptPath = "\(bundlePath)/Contents/python/transcription_server.py"
        
        // Create pipes for communication
        inputPipe = Pipe()
        outputPipe = Pipe()
        
        // Set up the process - use the virtual environment Python directly
        pythonProcess = Process()
        let venvPythonPath = "\(bundlePath)/Contents/.venv/bin/python"
        pythonProcess?.executableURL = URL(fileURLWithPath: venvPythonPath)
        pythonProcess?.arguments = [pythonScriptPath]
        pythonProcess?.standardInput = inputPipe
        pythonProcess?.standardOutput = outputPipe
        
        // Set up working directory to the app Contents directory
        let appContentsPath = "\(bundlePath)/Contents"
        pythonProcess?.currentDirectoryURL = URL(fileURLWithPath: appContentsPath)
        
        // Set up environment with Homebrew paths for FFmpeg
        var environment = ProcessInfo.processInfo.environment
        let homebrewPaths = "/opt/homebrew/bin:/usr/local/bin"
        if let currentPath = environment["PATH"] {
            environment["PATH"] = "\(homebrewPaths):\(currentPath)"
        } else {
            environment["PATH"] = "\(homebrewPaths):/usr/bin:/bin"
        }
        pythonProcess?.environment = environment
        
        // Debug logging
        Logger.shared.info("Bundle path: \(bundlePath)")
        Logger.shared.info("Python script path: \(pythonScriptPath)")
        Logger.shared.info("Python executable path: \(venvPythonPath)")
        Logger.shared.info("Working directory: \(appContentsPath)")
        
        // Start monitoring output
        setupOutputMonitoring()
        
        do {
            try pythonProcess?.run()
            Logger.shared.info("Python transcription server started successfully")
            
            // Send ping to verify connection
            sendCommand(["action": "ping"])
            
        } catch {
            Logger.shared.error("Failed to start Python server: \(error)")
        }
    }
    
    private func setupOutputMonitoring() {
        guard let outputPipe = outputPipe else { return }
        
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                let output = String(data: data, encoding: .utf8) ?? ""
                self?.handlePythonOutput(output)
            }
        }
    }
    
    private func handlePythonOutput(_ output: String) {
        Logger.shared.info("Python output received: \(output)")
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        for line in lines {
            do {
                let json = try JSONSerialization.jsonObject(with: line.data(using: .utf8)!, options: [])
                if let response = json as? [String: Any] {
                    Logger.shared.info("Parsed JSON response: \(response)")
                    handlePythonResponse(response)
                }
            } catch {
                Logger.shared.error("Failed to parse JSON response: \(line)")
            }
        }
    }
    
    private func handlePythonResponse(_ response: [String: Any]) {
        if let message = response["message"] as? String, message == "pong" {
            DispatchQueue.main.async {
                self.isInitialized = true
            }
            print("Python server is ready")
        } else if response["success"] != nil || response["error"] != nil {
            // This is a transcription response
            DispatchQueue.main.async {
                self.isProcessing = false
                self.onTranscriptionComplete?(response)
            }
        }
    }
    
    func transcribe(audioPath: String) {
        guard isInitialized, !isProcessing else {
            print("Cannot transcribe: server not ready or already processing")
            return
        }

        isProcessing = true

        // Get cleanup settings from UserDefaults
        let cleanupEnabled = UserDefaults.standard.bool(forKey: "cleanupEnabled")
        let cleanupPrompt = UserDefaults.standard.string(forKey: "cleanupPrompt") ?? "general"

        var command: [String: Any] = [
            "action": "transcribe",
            "audio_path": audioPath
        ]

        // Add cleanup prompt if enabled
        if cleanupEnabled {
            command["cleanup_prompt"] = cleanupPrompt
        }

        sendCommand(command)
    }
    
    private func sendCommand(_ command: [String: Any]) {
        guard let inputPipe = inputPipe else {
            print("Input pipe not available")
            return
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: command, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8)! + "\n"
            
            inputPipe.fileHandleForWriting.write(jsonString.data(using: .utf8)!)
            
        } catch {
            print("Failed to send command: \(error)")
        }
    }
    
    func cleanup() {
        if let process = pythonProcess, process.isRunning {
            // Send quit command
            sendCommand(["action": "quit"])
            
            // Give it a moment to shut down gracefully
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                if process.isRunning {
                    process.terminate()
                }
            }
        }
        
        inputPipe = nil
        outputPipe = nil
        pythonProcess = nil
        
        print("Transcription service cleaned up")
    }
    
    deinit {
        cleanup()
    }
}