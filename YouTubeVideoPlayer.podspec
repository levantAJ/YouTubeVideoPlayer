Pod::Spec.new do |s|
  s.name = 'YouTubeVideoPlayer'
  s.version = '1.0'
  s.summary = 'YouTube video player'
  s.description = <<-DESC
Library for embedding and controlling YouTube videos in your iOS applications written on Swift 4.2 by levantAJ
                       DESC
  s.homepage = 'https://github.com/levantAJ/YouTubeVideoPlayer'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.author = { 'Tai Le' => 'sirlevantai@gmail.com' }
  s.source = { :git => 'https://github.com/levantAJ/YouTubeVideoPlayer.git', :tag => s.version.to_s }
  s.ios.deployment_target = '9.0'
  s.swift_version = '4.2'
  s.source_files = 'YouTubeVideoPlayer/YouTubeVideoPlayer.swift'
  
end