Pod::Spec.new do |s|
  s.name         = "PKShortVideo"
  s.version      = “0.9.4”
  s.license      = "MIT"
  s.summary      = "A video library like WeChat short video for iOS."
  s.homepage     = "https://github.com/pepsikirk/PKShortVideo"
  s.social_media_url   = "http://weibo.com/u/1776530813"
  s.author             = { "pepsikirk" => "pepsikirk@gmail.com" }
  s.source       = { :git => "https://github.com/pepsikirk/PKShortVideo.git", :tag => s.version }
  s.screenshots  = "https://raw.githubusercontent.com/pepsikirk/PKShortVideo/master/Screenshots/gif.gif"
  s.platform     = :ios, "7.0"
  s.resources = "PKShortVideo/PKAsset/*.png"
  s.frameworks = "AVFoundation", "CoreMedia", "OpenGLES", "QuartzCore"
  s.requires_arc = true

  s.source_files = 'PKShortVideo/**/*.{h,m}' , 'PKShortVideo/*.{h,m}'

end
