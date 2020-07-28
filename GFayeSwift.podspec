Pod::Spec.new do |s|
  s.name             = "GFayeSwift"
  s.version          = "0.5.9"
  s.summary          = "A pure Swift Faye (Bayeux/CometD) Client"
  s.description      = <<-DESC
                        A Pure Swift Client Library for Faye/Bayeux/CometD Pub-Sub messaging server.
                        Currently only supports Websocket transport.
                        Ported from FayeSwift (https://github.com/hamin/FayeSwift) into Swift 4 and Swift 5.
                       DESC
  s.homepage         = "https://github.com/ckpwong/GFayeSwift"
  s.license          = "MIT"
  s.author           = { "Haris Amin" => "aminharis7@gmail.com", "Cindy Wong" => "ckpwong@gmail.com" }
  s.source           = { :git => "https://github.com/ckpwong/GFayeSwift.git", :tag => s.version.to_s }
  s.requires_arc = true
  s.osx.deployment_target = "10.10"
  s.ios.deployment_target = "8.0"
  s.tvos.deployment_target = "9.0"
  s.source_files = "Sources/GFayeSwift/*.swift"
  s.dependency "Starscream", '~> 3.1.0'
  s.dependency "SwiftyJSON", '~> 5.0.0'
  s.swift_versions   = [ "4.0", "4.2", "5.0" ]
end
