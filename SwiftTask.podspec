Pod::Spec.new do |s|
  s.name     = 'SwiftTask'
  s.version  = '0.0.1'
  s.license  = { :type => 'MIT' }
  s.homepage = 'https://github.com/inamiy/SwiftTask'
  s.authors  = { 'Yasuhiro Inami' => 'inamiy@gmail.com' }
  s.summary  = 'Promise + progress + pause + cancel, using SwiftState (state machine).'
  s.source   = { :git => 'https://github.com/inamiy/SwiftTask.git', :tag => "#{s.version}" }
  s.source_files = 'SwiftTask/*.{h,swift}'
  s.frameworks = 'Swift'
  s.requires_arc = true
end