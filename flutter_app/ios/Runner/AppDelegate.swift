import Flutter
import GoogleMaps
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps must be initialized before any map view is created.
    if let mapsApiKey = AppDelegate.envValue(for: "MAP_API_KEY") {
      GMSServices.provideAPIKey(mapsApiKey)
    }

    // Required for FCM / APNs on iOS
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Reads a value from the `.env` file bundled as a Flutter asset.
  private static func envValue(for key: String) -> String? {
    let assetKey = FlutterDartProject.lookupKey(forAsset: ".env")
    guard
      let path = Bundle.main.path(forResource: assetKey, ofType: nil),
      let contents = try? String(contentsOfFile: path, encoding: .utf8)
    else { return nil }

    for line in contents.components(separatedBy: .newlines) {
      let parts = line.split(separator: "=", maxSplits: 1).map {
        $0.trimmingCharacters(in: .whitespaces)
      }
      guard parts.count == 2, parts[0] == key else { continue }
      let value = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
      return value.isEmpty ? nil : value
    }
    return nil
  }
}
