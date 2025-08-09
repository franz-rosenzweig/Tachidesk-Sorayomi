import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Phase 5: Setup MethodChannel for security-scoped bookmark (custom downloads folder / iCloud)
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "sorayomi.storage/bookmark", binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "bookmarkFolder":
        self?.pickFolderAndCreateBookmark(result: result)
      case "resolveBookmark":
        guard let args = call.arguments as? [String: Any], let data = args["bookmark"] as? FlutterStandardTypedData else {
          result(FlutterError(code: "ARG", message: "Missing bookmark data", details: nil))
          return
        }
        let resolved = self?.resolveBookmark(data: data.data)
        result(resolved)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Present a UIDocumentPicker to choose a folder and create a security scoped bookmark
  private func pickFolderAndCreateBookmark(result: @escaping FlutterResult) {
    if #available(iOS 14.0, *) {
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
      if #available(iOS 13.0, *) {
        picker.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
      }
      picker.allowsMultipleSelection = false
      picker.delegate = self
      objc_setAssociatedObject(picker, &AssociatedKeys.bookmarkCallback, result, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
      window?.rootViewController?.present(picker, animated: true, completion: nil)
    } else {
      result(FlutterError(code: "UNSUPPORTED", message: "Folder picker requires iOS 14+", details: nil))
    }
  }

  private func resolveBookmark(data: Data) -> String? {
    var isStale = false
    do {
  // iOS does not support withSecurityScope for non-app groups in same way as macOS; resolve without those options
  let url = try URL(resolvingBookmarkData: data, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &isStale)
  return url.path
    } catch {
      return nil
    }
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    releaseAllSecurityScopedResources()
    super.applicationWillTerminate(application)
  }

  private func releaseAllSecurityScopedResources() {
    // Currently relying on automatic scope management; place manual stopAccessing calls here if retained URLs stored.
  }
}

private struct AssociatedKeys {
  static var bookmarkCallback = "bookmarkCallback"
}

extension AppDelegate: UIDocumentPickerDelegate {
  public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else {
      if let cb = objc_getAssociatedObject(controller, &AssociatedKeys.bookmarkCallback) as? FlutterResult {
        cb(FlutterError(code: "NO_URL", message: "No folder selected", details: nil))
      }
      return
    }
    do {
      let bookmark: Data
  // Remove withSecurityScope (macOS only); generate standard bookmark
  bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
      if let cb = objc_getAssociatedObject(controller, &AssociatedKeys.bookmarkCallback) as? FlutterResult {
        cb(bookmark)
      }
    } catch {
      if let cb = objc_getAssociatedObject(controller, &AssociatedKeys.bookmarkCallback) as? FlutterResult {
        cb(FlutterError(code: "BOOKMARK_FAIL", message: error.localizedDescription, details: nil))
      }
    }
  }
  public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    if let cb = objc_getAssociatedObject(controller, &AssociatedKeys.bookmarkCallback) as? FlutterResult {
      cb(FlutterError(code: "CANCELLED", message: "User cancelled", details: nil))
    }
  }
}
