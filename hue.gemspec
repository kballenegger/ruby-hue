# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hue/version'

Gem::Specification.new do |gem|
  gem.name          = 'ruby-hue'
  gem.version       = Hue::VERSION
  gem.authors       = ['Kenneth Ballenegger']
  gem.email         = ['kenneth@ballenegger.com']
  gem.description   = %q{Control Philips Hue}
  gem.summary       = %q{Control Philips Hue}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']
end
