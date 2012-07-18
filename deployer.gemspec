# -*- encoding: utf-8 -*-
require File.expand_path('../lib/deployer/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Ricky Dunlop"]
  gem.email         = ["ricky@rehabstudio.com"]
  gem.description   = %q{Features a modular design allowing it to be extended for various frameworks. Includes recipes for CakePHP, Lithium, MySQL, Nginx, Apache. Uses Railsless deploy}
  gem.summary       = %q{Deploy PHP apps using Capistrano}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "deployer"
  gem.require_paths = ["lib"]
  gem.version       = Deployer::VERSION
end