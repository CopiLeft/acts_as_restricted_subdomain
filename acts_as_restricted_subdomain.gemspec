Gem::Specification.new do |s|
  s.name          = 'acts_as_restricted_subdomain'
  s.version       = '3.0.0'
  s.authors       = ['Andrew Coleman', 'Taylor Redden']
  s.email         = 'developers@consoloservices.com'
  s.summary       = 'Acts As Restricted Subdomain'
  s.description   = 'Instead of destroying active record objects, mark a column as deleted with a timestamp'
  s.homepage      = 'https://redmine.consoloservices.com'
  s.require_path  = '.'
  s.files         = Dir["{lib}/*.rb", "LICENSE", "README"]

  s.add_dependency 'activerecord', '~> 3.0'  
end
