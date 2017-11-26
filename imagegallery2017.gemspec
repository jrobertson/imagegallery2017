Gem::Specification.new do |s|
  s.name = 'imagegallery2017'
  s.version = '0.1.0'
  s.summary = 'An experimental personal project to build a ' + 
     'basic ImageGallery. Uses an external object for processing images sizes.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/imagegallery2017.rb']
  s.add_runtime_dependency('dynarex', '~> 1.7', '>=1.7.26')
  s.add_runtime_dependency('nokogiri', '~> 1.8', '>=1.8.1')
  s.signing_key = '../privatekeys/imagegallery2017.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/imagegallery2017'
end
