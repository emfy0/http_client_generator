# frozen_string_literal: true

module HttpClientGenerator
  module KeyTransformer # :nodoc:
    module_function

    def deep_transform_keys(value, &block)
      case value
      when Hash
        value.each_with_object({}) do |(key, hash_value), transformed|
          transformed[yield(key)] = deep_transform_keys(hash_value, &block)
        end
      when Array
        value.map { |item| deep_transform_keys(item, &block) }
      else
        value
      end
    end
  end
end
