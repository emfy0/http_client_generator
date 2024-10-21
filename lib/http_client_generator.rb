# frozen_string_literal: true

require 'zeitwerk'

require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/hash/keys'

Zeitwerk::Loader.for_gem.setup

Dir["#{__dir__}/http_client_generator/plugs/*.rb"].each { |f| require f }

module HttpClientGenerator
  def self.included(base)
    super

    base.extend(self)
    base.const_set(:Error, Class.new(StandardError))
    base.const_set(:RequestError, Class.new(base::Error))
  end

  def url_helper(module_name)
    @url_helper = module_name
  end

  def resources(&block)
    resources_definition = ResourcesDefinition.new(self)
    resources_definition.instance_eval(&block)
    resources = resources_definition.resources

    resources.each do |resource|
      method_name = :"#{resource.verb}_#{resource.name}"

      define_singleton_method(method_name) do |url_options = {}, body: nil, **rest_args|
        resource.perform_request(@url_helper, url_options, body, rest_args)
      end
    end
  end

  attr_reader :config

  def configure(&configure)
    @config = self::Configuration.new
      .tap(&configure)
      .tap { |c| user_process_config(c) if respond_to?(:user_process_config) }
      .tap(&:freeze)
  end

  def process_config(&block)
    define_singleton_method(:user_process_config, block)
  end
end
