$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "ignorable_columns/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "ignorable_columns"
  s.version     = IgnorableColumns::VERSION
  s.authors     = ["Calin Ciobanu"]
  s.email       = ["ciobanu.calin@gmail.com"]
  s.homepage    = "https://github.com/calin-ciobanu/ignorable_columns"
  s.summary     = "Inspired by ignorable gem with several enhancements."
  s.description = "Inspired by ignorable gem with support for sql queries ignore columns and bypass ignored columns on demand"
  s.license     = "MIT"

  s.add_runtime_dependency 'activerecord', '>= 3', '< 5'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '>= 3'

  s.files = Dir["{lib}/**/*"]
end
