Pod::Spec.new do |s|
  s.name     = 'SwiftTask'
  s.version  = '2.5.1'
  s.license  = { :type => 'MIT' }
  s.homepage = 'https://github.com/ReactKit/SwiftTask'
  s.authors  = { 'Yasuhiro Inami' => 'inamiy@gmail.com' }
  s.summary  = 'Promise + progress + pause + cancel + retry, using SwiftState (state machine).'
  s.source   = { :git => 'https://github.com/inamiy/SwiftTask.git', :tag => "#{s.version}" }
  s.source_files = 'SwiftTask/**/*.{h,swift}'
  s.requires_arc = true
  
  s.dependency 'SwiftState', '~> 1.1.1'
end