require 'rubygems'
require 'rake/testtask'
require 'rubygems/package_task'
require 'rspec/core/rake_task'

spec = Gem::Specification.new do |gem|
    gem.name         = "hiera-ic-yaml"
    gem.version      = "1.2.0"
    gem.summary      = "ic yaml backend"
    gem.email        = "fabio.bat.silva@gmail.com"
    gem.author       = "Fabio B. Silva"
    gem.homepage     = "http://github.com/instaclick/hiera-ic-yaml"
    gem.description  = "Hiera yaml backend that support imports and parameters"
    gem.require_path = "lib"
    gem.files        = FileList["lib/**/*"].to_a
    gem.add_runtime_dependency 'hiera', '1.3.0'
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = 'spec/**/*_spec.rb'
end

task :test => :spec

task :default do
  sh 'rake -T'
end