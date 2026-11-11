import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var audioRecorder: AVAudioRecorder?
  private var currentAudioPath: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "org.caritasnigeria.voteguard/foreground_audio",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        switch call.method {
        case "startAudioRecording":
          guard let args = call.arguments as? [String: Any],
                let path = args["path"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Output path is required", details: nil))
            return
          }
          self.requestAndStartAudioRecording(path: path, result: result)
        case "stopAudioRecording":
          let savedPath = self.stopAudioRecordingInternal()
          result(savedPath)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureAudioSession(active: Bool) {
    let session = AVAudioSession.sharedInstance()
    do {
      if active {
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
      } else {
        try session.setActive(false, options: .notifyOthersOnDeactivation)
      }
    } catch {
      NSLog("VoteGuard AudioSession error: %@", error.localizedDescription)
    }
  }

  private func requestAndStartAudioRecording(path: String, result: @escaping FlutterResult) {
    let session = AVAudioSession.sharedInstance()
    session.requestRecordPermission { [weak self] granted in
      DispatchQueue.main.async {
        guard let self = self else { return }
        if !granted {
          result(FlutterError(code: "PERMISSION_DENIED", message: "Microphone permission denied", details: nil))
          return
        }
        do {
          self.configureAudioSession(active: true)
          let url = URL(fileURLWithPath: path)
          try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
          )
          let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
          ]
          let recorder = try AVAudioRecorder(url: url, settings: settings)
          recorder.prepareToRecord()
          if recorder.record() {
            self.audioRecorder = recorder
            self.currentAudioPath = path
            result(true)
          } else {
            result(FlutterError(code: "RECORDER_FAILED", message: "Could not start AVAudioRecorder", details: nil))
          }
        } catch {
          result(FlutterError(code: "RECORDER_ERROR", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func stopAudioRecordingInternal() -> String? {
    let path = currentAudioPath
    audioRecorder?.stop()
    audioRecorder = nil
    currentAudioPath = nil
    configureAudioSession(active: false)
    return path
  }
}
