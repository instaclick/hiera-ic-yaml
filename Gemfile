source ENV['GEM_SOURCE'] || "https://rubygems.org"

gem "hiera"

group :development do
  gem 'watchr'
end

group :development, :test do
  gem 'rake', "~> 10.1.0"
  gem 'rspec', "~> 2.11.0", :require => false
  gem 'mocha', "~> 0.10.5", :require => false
  gem 'json', "~> 1.7", :require => false, :platforms => :ruby
  gem "yarjuf", "~> 1.0"
end


require 'yaml'

if File.exists? "#{__FILE__}.local"
  eval(File.read("#{__FILE__}.local"), binding)
end

# vim:ft=ruby
