Pod::Spec.new do |s|
  s.name     = 'SwiftTask'
  s.version  = '3.3.1'
  s.license  = { :type => 'MIT' }
  s.homepage = 'https://github.com/ReactKit/SwiftTask'
  s.authors  = { 'Yasuhiro Inami' => 'inamiy@gmail.com' }
  s.summary  = 'Promise + progress + pause + cancel + retry for Swift.'
  s.source   = { :git => 'https://github.com/ReactKit/SwiftTask.git', :tag => "#{s.version}" }
  s.source_files = 'SwiftTask/**/*.{h,swift}'
  s.requires_arc = true

  s.osx.deployment_target = '10.9'
  s.ios.deployment_target = '8.0'
end