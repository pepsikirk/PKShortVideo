Pod::Spec.new do |s|
  s.name         = "PKShortVideo"
  s.version      = "0.9.5"
  s.license      = "MIT"
  s.summary      = "A video library like WeChat short video for iOS."
  s.homepage     = "https://github.com/pepsikirk/PKShortVideo"
  s.author             = { "pepsikirk" => "pepsikirk@gmail.com" }
  s.source       = { :git => "https://github.com/pepsikirk/PKShortVideo.git", :tag => s.version }
  s.screenshots  = "https://raw.githubusercontent.com/pepsikirk/PKShortVideo/master/Screenshots/gif.gif"
  s.platform     = :ios, "12.0"
  s.resources = "PKShortVideo/PKAsset/*.png"
  s.frameworks = "AVFoundation", "CoreMedia", "CoreVideo", "OpenGLES", "QuartzCore"
  s.requires_arc = true
  s.pod_target_xcconfig = {
    "GCC_PREPROCESSOR_DEFINITIONS" => "$(inherited) GLES_SILENCE_DEPRECATION=1 COREVIDEO_SILENCE_GL_DEPRECATION=1"
  }

  s.source_files = 'PKShortVideo/**/*.{h,m}' , 'PKShortVideo/*.{h,m}'

end
