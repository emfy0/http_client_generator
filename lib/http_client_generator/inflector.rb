# frozen_string_literal: true

module HttpClientGenerator
  module Inflector # :nodoc:
    module_function

    def camelize_lower(value)
      value.to_s.split('_').then do |parts|
        [parts.first, *parts.drop(1).map(&:capitalize)].join
      end
    end

    def underscore(value)
      value.to_s
           .gsub('::', '/')
           .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
           .gsub(/([a-z\d])([A-Z])/, '\1_\2')
           .tr('-', '_')
           .downcase
    end
  end
end
