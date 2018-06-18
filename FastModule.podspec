Pod::Spec.new do |s|
  s.name         = "FastModule"
  s.version      = "0.0.1"
  s.summary      = "short description of FastModule."
  s.description  = "description"
  s.homepage     = "http://github.com/FastModule"
  s.license      = "MIT"
  s.author             = { "luoxu" => "ianluo63@gmail.com" }
  s.source       = { :git => "http://github.com/FastModule.git", :tag => "#{s.version}" }
  s.source_files  = "Sources/**/*.swift"
end
