Pod::Spec.new do |spec|
  spec.name = "appssembleComunicationFramework"
  spec.version = "1.0.0"
  spec.summary = "Comunication framework based on multipeer connectivity and WebRTC, it provides real time communication and time synchronization."
  spec.description  = "Comunication framework based on multipeer connectivity and WebRTC, it provides real time communication and time synchronization. It uses libjingle, WebRTC, SocketRocket, ntp and the MultiplayerConnectivity Framework. It provides 2 types of communication, via RTC and by using muliplayer connectivity in the local network."

  spec.homepage = "https://github.com/appssemble/appssembleCommunicationFramework"
  spec.license = { type: 'WTFPL', file: 'LICENSE' }
  spec.authors = { "Dragos Dobrean" => 'dragos@appssemble.com' }
  spec.social_media_url = "http://www.appssemble.com"

  spec.ios.deployment_target = '9.0'
  spec.requires_arc = true
  spec.source = { git: "https://github.com/appssemble/appssembleCommunicationFramework.git", tag: "v#{spec.version}", submodules: false }
  spec.source_files = "**/*.{h,swift,m}"
end