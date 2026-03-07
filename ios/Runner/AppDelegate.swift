import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Flutter 에셋 .env에서 Google Maps API 키 로드
    if let envURL = Bundle.main.url(
      forResource: ".env",
      withExtension: nil,
      subdirectory: "Frameworks/App.framework/flutter_assets"
    ) {
      if let contents = try? String(contentsOf: envURL, encoding: .utf8) {
        for line in contents.components(separatedBy: "\n") {
          let parts = line.components(separatedBy: "=")
          if parts.first?.trimmingCharacters(in: .whitespaces) == "GOOGLE_MAPS_API_KEY",
             parts.count >= 2 {
            let apiKey = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
            if !apiKey.isEmpty {
              GMSServices.provideAPIKey(apiKey)
            }
            break
          }
        }
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
