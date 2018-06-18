Pod::Spec.new do |s|
  s.name         = "FastModule"
  s.version      = "0.0.1"
  s.summary      = "short description of FastModule."
  s.description  = "description"
  s.homepage     = "https://github.com/IanLuo/FastModule"
  s.license      = "MIT"
  s.author             = { "luoxu" => "ianluo63@gmail.com" }
  s.source       = { :git => "git@github.com:IanLuo/FastModule.git", :tag => "#{s.version}" }
  s.source_files  = "Sources/**/*.swift"
end
