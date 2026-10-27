Pod::Spec.new do |s|
  s.name             = 'docukit_native'
  s.version          = '1.0.0'
  s.summary          = 'DocuKit native file bridge (save as, open with, free space, background task).'
  s.description      = 'Local plugin for DocuKit. Streams from file paths; no network.'
  s.homepage         = 'https://example.invalid/docukit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'DocuKit' => 'docukit@example.invalid' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.frameworks = 'QuickLook'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  # Disk-space and file-timestamp required-reason APIs are declared in the app's PrivacyInfo.xcprivacy.
end
