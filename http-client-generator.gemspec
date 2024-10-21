# frozen_string_literal: true

require_relative "lib/http_client_generator/version"

Gem::Specification.new do |spec|
  spec.name = "http-client-generator"
  spec.version = HttpClientGenerator::VERSION
  spec.authors = ["Pavel Egorov"]
  spec.email = ['moonmeander47@ya.ru']

  spec.summary = 'Ruby Http Client generator'
  spec.description = 'Ruby Http Client generator'
  spec.required_ruby_version = '>= 3.1'

  spec.files = Dir['lib/**/*.rb', 'README.md']
  spec.require_paths = ['lib']

  spec.add_dependency('http', '~> 5.2')
  spec.add_dependency('zeitwerk', '~> 2.6')
end
