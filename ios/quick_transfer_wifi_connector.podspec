#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint quick_transfer_wifi_connector.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'quick_transfer_wifi_connector'
  s.version          = '0.0.1'
  s.summary          = 'System-confirmed Wi-Fi joins for temporary device AP transfer flows.'
  s.description      = <<-DESC
Opens Android and iOS system confirmation flows for joining temporary Wi-Fi
access points, such as device file-transfer hotspots.
                       DESC
  s.homepage         = 'https://example.com/quick_transfer_wifi_connector'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'qtx' => 'qtx@example.com' }
  s.source           = { :path => '.' }
  s.requires_arc     = true
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.frameworks = 'NetworkExtension', 'UIKit'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'APPLICATION_EXTENSION_API_ONLY' => 'NO',
    'CLANG_ENABLE_MODULES' => 'YES',
    'DEFINES_MODULE' => 'YES',
    'ENABLE_BITCODE' => 'NO',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'IPHONEOS_DEPLOYMENT_TARGET' => '12.0',
    'SWIFT_VERSION' => '5.0'
  }
  s.swift_version = '5.0'
end
