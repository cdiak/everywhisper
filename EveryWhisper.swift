// everywhisper — system-wide local Whisper dictation for macOS
// https://github.com/cdiak/everywhisper
//
// Option+Shift+W → toggle record → transcribe locally → paste into focused app.
//
// Build:   ./build.sh
// Install: ./install.sh

import AppKit
import AVFoundation
import Carbon
import Foundation

// MARK: - Config

struct Config {
    var whisperBinary: String
    var modelPath: String
    var language: String
    var threads: Int

    static func load() -> Config {
        let env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        let whisper =
            env["WHISPER_CLI"]
            ?? which("whisper-cli")
            ?? "/opt/homebrew/bin/whisper-cli"

        let model =
            env["WHISPER_MODEL"]
            ?? discoverModel(home: home)
            ?? "\(home)/.cache/whisper/ggml-base.en.bin"

        let language = env["WHISPER_LANGUAGE"] ?? "en"
        let threads = Int(env["WHISPER_THREADS"] ?? "")
            ?? max(2, ProcessInfo.processInfo.processorCount / 2)

        return Config(
            whisperBinary: whisper,
            modelPath: model,
            language: language,
            threads: threads
        )
    }

    private static func discoverModel(home: String) -> String? {
        let candidates = [
            "\(home)/.cache/whisper/ggml-base.en.bin",
            "\(home)/models/whisper/ggml-base.en.bin",
            "/opt/homebrew/share/whisper-cpp/ggml-base.en.bin",
            "/usr/local/share/whisper-cpp/ggml-base.en.bin",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private static func which(_ cmd: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        p.arguments = [cmd]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do {
            try p.run()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { return nil }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            let s = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (s?.isEmpty == false) ? s : nil
        } catch {
            return nil
        }
    }
}

// MARK: - Paste into focused app

enum PasteboardInjector {
    /// Copy text, then simulate ⌘V into the frontmost app.
    /// Requires Accessibility permission.
    static func paste(_ text: String) {
        guard !text.isEmpty else { return }

        let pb = NSPasteboard.general
        let previousString = pb.string(forType: .string)

        pb.clearContents()
        pb.setString(text, forType: .string)

        usleep(80_000)

        let source = CGEventSource(stateID: .hidSystemState)
        let vKey: CGKeyCode = 0x09 // kVK_ANSI_V

        if let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true) {
            down.flags = .maskCommand
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) {
            up.flags = .maskCommand
            up.post(tap: .cghidEventTap)
        }

        if let previousString {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                pb.clearContents()
                pb.setString(previousString, forType: .string)
            }
        }
    }
}

// MARK: - Recorder + Whisper

final class DictationEngine {
    private let config: Config
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private(set) var isRecording = false
    private var isBusy = false

    var onStateChange: ((String) -> Void)?

    init(config: Config) {
        self.config = config
    }

    func toggle() {
        if isBusy {
            NSSound.beep()
            return
        }
        if isRecording {
            stopAndTranscribe()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        let sessionOK = requestMicAccessSync()
        guard sessionOK else {
            notify(
                "Microphone access denied. Enable it in System Settings → Privacy & Security → Microphone."
            )
            NSSound.beep()
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("everywhisper-\(UUID().uuidString).wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.isMeteringEnabled = false
            guard rec.record() else {
                notify("Could not start microphone recording.")
                NSSound.beep()
                return
            }
            recorder = rec
            recordingURL = url
            isRecording = true
            onStateChange?("recording")
            NSSound(named: .init("Tink"))?.play()
            fputs("● Recording… (Option+Shift+W to stop)\n", stderr)
        } catch {
            notify("Recording failed: \(error.localizedDescription)")
            NSSound.beep()
        }
    }

    private func stopAndTranscribe() {
        guard let rec = recorder, let url = recordingURL else { return }
        rec.stop()
        recorder = nil
        isRecording = false
        isBusy = true
        onStateChange?("transcribing")
        NSSound(named: .init("Pop"))?.play()
        fputs("… Transcribing…\n", stderr)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            defer {
                try? FileManager.default.removeItem(at: url)
                let txt = url.deletingPathExtension().appendingPathExtension("txt")
                try? FileManager.default.removeItem(at: txt)
            }

            do {
                let text = try self.transcribe(wav: url)
                DispatchQueue.main.async {
                    self.isBusy = false
                    self.onStateChange?("idle")
                    if text.isEmpty {
                        fputs("(no speech detected)\n", stderr)
                        NSSound.beep()
                    } else {
                        fputs("→ \(text)\n", stderr)
                        PasteboardInjector.paste(text)
                        NSSound(named: .init("Glass"))?.play()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isBusy = false
                    self.onStateChange?("idle")
                    self.notify("Whisper failed: \(error.localizedDescription)")
                    NSSound.beep()
                    fputs("error: \(error)\n", stderr)
                }
            }
        }
    }

    private func transcribe(wav: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: config.whisperBinary) else {
            throw NSError(
                domain: "EveryWhisper",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "whisper-cli not found at \(config.whisperBinary). Install whisper.cpp or set WHISPER_CLI."
                ]
            )
        }
        guard FileManager.default.fileExists(atPath: config.modelPath) else {
            throw NSError(
                domain: "EveryWhisper",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Model not found at \(config.modelPath). Set WHISPER_MODEL to a ggml/gguf model file."
                ]
            )
        }

        let outBase = wav.deletingPathExtension().path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: config.whisperBinary)
        process.arguments = [
            "-m", config.modelPath,
            "-f", wav.path,
            "-l", config.language,
            "-t", String(config.threads),
            "-otxt",
            "-of", outBase,
            "-np",
        ]
        let errPipe = Pipe()
        process.standardOutput = Pipe()
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let errText = String(data: errData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "EveryWhisper",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "whisper-cli exited \(process.terminationStatus): \(errText)"
                ]
            )
        }

        let txtURL = URL(fileURLWithPath: outBase + ".txt")
        let raw = try String(contentsOf: txtURL, encoding: .utf8)
        return raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }

    private func requestMicAccessSync() -> Bool {
        let sem = DispatchSemaphore(value: 0)
        var granted = false
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { ok in
                granted = ok
                sem.signal()
            }
            _ = sem.wait(timeout: .now() + 60)
            return granted
        default:
            return false
        }
    }

    private func notify(_ message: String) {
        fputs("everywhisper: \(message)\n", stderr)
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine: DictationEngine!
    private var statusItem: NSStatusItem?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = Config.load()
        engine = DictationEngine(config: config)
        engine.onStateChange = { [weak self] state in
            self?.updateStatus(state)
        }

        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )
        if !trusted {
            fputs(
                """
                everywhisper: grant Accessibility access so text can be pasted into other apps.
                  System Settings → Privacy & Security → Accessibility → enable everywhisper
                (You may need to restart this app after granting.)

                """,
                stderr
            )
        }

        fputs(
            """
            everywhisper ready
              hotkey:  Option+Shift+W  (toggle record / stop+paste)
              whisper: \(config.whisperBinary)
              model:   \(config.modelPath)
              lang:    \(config.language)

            """,
            stderr
        )

        setupStatusItem()
        registerHotkey()
        updateStatus("idle")
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "W"
            button.toolTip = "everywhisper — Option+Shift+W"
        }
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Toggle Dictation (⌥⇧W)",
                action: #selector(toggleFromMenu),
                keyEquivalent: ""
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func updateStatus(_ state: String) {
        switch state {
        case "recording":
            statusItem?.button?.title = "●"
        case "transcribing":
            statusItem?.button?.title = "…"
        default:
            statusItem?.button?.title = "W"
        }
    }

    @objc private func toggleFromMenu() {
        engine.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func registerHotkey() {
        // Option+Shift+W
        let hotKeyID = EventHotKeyID(signature: OSType(0x45565753), id: 1) // 'EVWS'
        let keyCode = UInt32(kVK_ANSI_W)
        let modifiers = UInt32(optionKey | shiftKey)

        var handlerSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData else { return noErr }
                let app = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                var hk = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hk
                )
                if hk.id == 1 {
                    DispatchQueue.main.async {
                        app.engine.toggle()
                    }
                }
                return noErr
            },
            1,
            &handlerSpec,
            userData,
            &eventHandler
        )

        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}

// MARK: - main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
