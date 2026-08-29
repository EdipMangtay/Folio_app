import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FolioICloudBackup.bind(to: engineBridge.applicationRegistrar.messenger())
  }
}

/// Writes folio-wallet.json into the user's private iCloud container.
private final class FolioICloudBackup: NSObject {
  static let fileName = "folio-wallet.json"
  static let containerId = "iCloud.com.folio.wallet"
  static let queue = DispatchQueue(label: "folio.wallet.icloud", qos: .userInitiated)

  static func bind(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "folio.wallet/icloud", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      queue.async {
        switch call.method {
        case "available":
          reply(result, FileManager.default.ubiquityIdentityToken != nil)
        case "modifiedAt":
          reply(result, FolioICloudBackup.modifiedAt())
        case "upload":
          guard let json = call.arguments as? String else {
            fail(result, code: "bad_args", message: "Yedek yazılamadı.")
            return
          }
          do {
            try FolioICloudBackup.upload(json)
            reply(result, nil)
          } catch {
            fail(result, code: "icloud", message: error.localizedDescription)
          }
        case "download":
          do {
            reply(result, try FolioICloudBackup.download())
          } catch {
            fail(result, code: "icloud", message: error.localizedDescription)
          }
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
        }
      }
    }
  }

  static func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  static func fail(_ result: @escaping FlutterResult, code: String, message: String) {
    DispatchQueue.main.async {
      result(FlutterError(code: code, message: message, details: nil))
    }
  }

  static func backupURL() throws -> URL {
    guard FileManager.default.ubiquityIdentityToken != nil else {
      throw FolioICloudError.signedOut
    }
    guard let container = FileManager.default.url(forUbiquityContainerIdentifier: containerId) else {
      throw FolioICloudError.unavailable
    }
    let documents = container.appendingPathComponent("Documents", isDirectory: true)
    try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
    return documents.appendingPathComponent(fileName)
  }

  static func upload(_ json: String) throws {
    let url = try backupURL()
    guard let data = json.data(using: .utf8) else { throw FolioICloudError.writeFailed }
    var coordinatorError: NSError?
    var writeError: Error?
    NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { destination in
      do {
        try data.write(to: destination, options: .atomic)
      } catch {
        writeError = error
      }
    }
    if let coordinatorError { throw coordinatorError }
    if let writeError { throw writeError }
  }

  static func download() throws -> String? {
    let url = try backupURL()
    try? FileManager.default.startDownloadingUbiquitousItem(at: url)
    let deadline = Date().addingTimeInterval(12)
    while Date() < deadline && !FileManager.default.fileExists(atPath: url.path) {
      Thread.sleep(forTimeInterval: 0.25)
    }
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }

    var coordinatorError: NSError?
    var payload: String?
    var readError: Error?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatorError) { source in
      do {
        payload = try String(contentsOf: source, encoding: .utf8)
      } catch {
        readError = error
      }
    }
    if let coordinatorError { throw coordinatorError }
    if let readError { throw readError }
    return payload
  }

  static func modifiedAt() -> String? {
    guard let url = try? backupURL(),
          FileManager.default.fileExists(atPath: url.path),
          let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
          let date = values.contentModificationDate else {
      return nil
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
  }
}

private enum FolioICloudError: LocalizedError {
  case signedOut
  case unavailable
  case writeFailed

  var errorDescription: String? {
    switch self {
    case .signedOut:
      return "iCloud kapalı. iPhone Ayarları’ndan iCloud’a giriş yap, sonra tekrar dene."
    case .unavailable:
      return "iCloud klasörüne ulaşılamadı. Cihazın internetini ve iCloud Drive’ı kontrol et."
    case .writeFailed:
      return "iCloud yedeği yazılamadı."
    }
  }
}
