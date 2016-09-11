Pod::Spec.new do |s|
  s.name         = "PKShortVideo"
  s.version      = "0.9.1"
  s.summary      = "A video library like WeChat short video for iOS."
  s.homepage     = "https://github.com/pepsikirk/PKShortVideo"
  s.screenshots  = "https://raw.githubusercontent.com/pepsikirk/PKShortVideo/master/Screenshots/gif.gif"
  s.license      = "MIT"
  s.author             = { "pepsikirk" => "pepsikirk@gmail.com" }
  s.social_media_url   = "http://weibo.com/u/1776530813"
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/pepsikirk/PKShortVideo.git", :tag => s.version }
  s.source_files = 'PKShortVideo/**/*.{h,m}'
  s.resources = "PKShortVideo/PKAsset/*.png"
  s.frameworks = "AVFoundation", "CoreMedia", "OpenGLES", "QuartzCore"
  s.requires_arc = true

end
