import Flutter
import QuickLook
import UIKit

/// DocuKit native bridge (ARCHITECTURE §6.4). Works on file URLs only and never
/// logs names or paths.
public class DocukitNativePlugin: NSObject, FlutterPlugin {
  private var pendingSave: FlutterResult?
  private var exportDir: URL?
  private var interaction: UIDocumentInteractionController?
  private var previewURL: URL?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "docukit/native", binaryMessenger: registrar.messenger())
    let instance = DocukitNativePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "saveAs":
      saveAs(args: args, result: result)
    case "openWith":
      openWith(args: args, result: result)
    case "freeBytes":
      result(freeBytes())
    case "beginBackgroundTask":
      var token = UIBackgroundTaskIdentifier.invalid
      token = UIApplication.shared.beginBackgroundTask(withName: args["name"] as? String) {
        // Expired: the job is recorded as Interrupted at next launch if the process dies.
        UIApplication.shared.endBackgroundTask(token)
      }
      result(token.rawValue)
    case "endBackgroundTask":
      if let raw = args["token"] as? Int {
        UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: raw))
      }
      result(nil)
    case "protectOutput":
      if let path = args["path"] as? String { protect(path: path) }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Save As (document picker in export mode)

  private func saveAs(args: [String: Any], result: @escaping FlutterResult) {
    guard pendingSave == nil else {
      result(["status": "failed", "code": "busy"])
      return
    }
    guard let path = args["path"] as? String, let top = Self.topViewController() else {
      result(["status": "failed", "code": "no_view_controller"])
      return
    }
    let name = (args["name"] as? String) ?? URL(fileURLWithPath: path).lastPathComponent
    // The exported file keeps its file name, so stage a copy with the suggested name.
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("export", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let staged = dir.appendingPathComponent(name)
    do {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: staged)
    } catch {
      result(["status": "failed", "code": "stage_failed"])
      return
    }
    exportDir = dir
    pendingSave = result
    let picker = UIDocumentPickerViewController(forExporting: [staged], asCopy: true)
    picker.delegate = self
    picker.modalPresentationStyle = .formSheet
    top.present(picker, animated: true)
  }

  private func finishSave(_ payload: [String: Any]) {
    if let dir = exportDir { try? FileManager.default.removeItem(at: dir) }
    exportDir = nil
    pendingSave?(payload)
    pendingSave = nil
  }

  // MARK: - Open with…

  private func openWith(args: [String: Any], result: @escaping FlutterResult) {
    guard let path = args["path"] as? String, let top = Self.topViewController() else {
      result(false)
      return
    }
    let url = URL(fileURLWithPath: path)
    let controller = UIDocumentInteractionController(url: url)
    controller.delegate = self
    interaction = controller
    let rect = Self.rect(from: args["origin"], in: top.view)
    if controller.presentOpenInMenu(from: rect, in: top.view, animated: true) {
      result(true)
      return
    }
    // No "Open in" targets: fall back to Quick Look so the user can still view it.
    guard QLPreviewController.canPreview(url as QLPreviewItem) else {
      result(false)
      return
    }
    previewURL = url
    let preview = QLPreviewController()
    preview.dataSource = self
    top.present(preview, animated: true)
    result(true)
  }

  // MARK: - Storage

  private func freeBytes() -> Int64 {
    let home = URL(fileURLWithPath: NSHomeDirectory())
    if let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
      let cap = values.volumeAvailableCapacityForImportantUsage
    {
      return cap
    }
    return 0
  }

  private func protect(path: String) {
    var url = URL(fileURLWithPath: path)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? url.setResourceValues(values)
    try? FileManager.default.setAttributes(
      [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
      ofItemAtPath: path)
  }

  // MARK: - Helpers

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.first?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  private static func rect(from raw: Any?, in view: UIView) -> CGRect {
    if let m = raw as? [String: Double], let x = m["x"], let y = m["y"], let w = m["w"], let h = m["h"] {
      return CGRect(x: x, y: y, width: max(w, 1), height: max(h, 1))
    }
    // iPad needs a non-zero anchor; default to the bottom centre.
    return CGRect(x: view.bounds.midX, y: view.bounds.maxY - 80, width: 1, height: 1)
  }
}

extension DocukitNativePlugin: UIDocumentPickerDelegate {
  public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finishSave(["status": "saved", "name": urls.first?.lastPathComponent as Any])
  }

  public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishSave(["status": "cancelled"])
  }
}

extension DocukitNativePlugin: UIDocumentInteractionControllerDelegate {
  public func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
    interaction = nil
  }
}

extension DocukitNativePlugin: QLPreviewControllerDataSource {
  public func numberOfPreviewItems(in controller: QLPreviewController) -> Int { previewURL == nil ? 0 : 1 }

  public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
    return (previewURL ?? URL(fileURLWithPath: "/")) as QLPreviewItem
  }
}
