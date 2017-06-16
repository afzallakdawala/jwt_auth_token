Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'jwt_auth_token'
  s.version     = '1.0.5'
  s.date        = '2017-06-12'
  s.summary     = "Json web token, setting data to header"
  s.description = ""
  s.authors     = ["Afzal Lakdawala"]
  s.email       = 'afzalmlakdawala@gmail.com'
  s.files       = Dir['lib/*.rb']
  s.homepage    =
    'http://rubygems.org/gems/jwt_auth_token'
  s.license       = 'MIT'
  s.post_install_message = "Thanks for installing!"
  %w(jwt moped rest-client).map {|gem| s.add_runtime_dependency gem}
end