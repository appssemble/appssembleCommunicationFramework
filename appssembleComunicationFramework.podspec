Pod::Spec.new do |spec|
  spec.name = "appssembleComunicationFramework"
  spec.version = "1.0.0"
  spec.summary = "Comunication framework based on multipeer connectivity and WebRTC, it provides real time communication and time synchronization."
  spec.description  = "Comunication framework based on multipeer connectivity and WebRTC, it provides real time communication and time synchronization. It uses libjingle, WebRTC, SocketRocket, ntp and the MultiplayerConnectivity Framework. It provides 2 types of communication, via RTC and by using muliplayer connectivity in the local network."

  spec.homepage = "https://github.com/appssemble/appssembleCommunicationFramework"
  spec.license = { type: 'WTFPL', text: '     DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE 
                    Version 2, December 2004 

 Copyright (C) 2017 <office@appssemble.com> 

 Everyone is permitted to copy and distribute verbatim or modified 
 copies of this license document, and changing it is allowed as long 
 as the name is changed. 

            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE 
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION 

  0. You just DO WHAT THE FUCK YOU WANT TO.' }
  spec.authors = { "Dragos Dobrean" => 'dragos@appssemble.com' }
  spec.social_media_url = "http://www.appssemble.com"

  spec.ios.deployment_target = '9.0'
  spec.requires_arc = true
  spec.source = { git: "https://github.com/appssemble/appssembleCommunicationFramework.git", tag: "v#{spec.version}", submodules: false }
  spec.source_files = "appssembleComunicationFramework/**/*.{h,m}"
 
  spec.frameworks = 'GLKit', 'CoreFoundation', 'CFNetwork', 'CoreAudio', 'CoreGraphics', 'CoreMedia', 'CoreVideo', 'OpenGLES', 'AVFoundation', 'VideoToolbox', 'Security', 'QuartzCore', 'Foundation', 'MultipeerConnectivity' 
  spec.libraries = 'c++', 'icucore'
  spec.vendored_libraries = 'appssembleComunicationFramework/Libs/libWebRTC.a'
  spec.xcconfig = { 'LIBRARY_SEARCH_PATHS' => "$(inherited) $(PROJECT_DIR)/appssembleComunicationFramework/Libs/**" }
end

