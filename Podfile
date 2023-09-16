# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
source 'https://github.com/CocoaPods/Specs.git'
platform :osx, '10.14'

target 'V2rayU' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for V2rayU
  pod 'AppCenter'
  pod 'Alamofire'
  pod 'SwiftyJSON'
  # master branch
  pod 'Preferences', :git => 'https://github.com/sindresorhus/Preferences.git'
  pod 'Sparkle'
  pod 'QRCoder'
  pod 'MASShortcut'
  pod 'Swifter'
  pod 'Yams'
  
end

# fix libarclite_macosx.a need min deploy target 10.14
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.14'
    end
  end
end
