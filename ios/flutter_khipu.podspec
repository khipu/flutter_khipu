#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_khipu.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_khipu'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for Khipu payments.'
  s.description      = <<-DESC
Flutter plugin for Khipu, this plugin enables a flutter app to use Khipu to authorize payments.
                       DESC
  s.homepage         = 'https://github.com/khipu/flutter_khipu'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Khipu' => 'developers@khipu.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_khipu/Sources/flutter_khipu/**/*.swift'
  s.dependency 'Flutter'
  s.dependency 'KhipuClientIOS', '2.16.4'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
