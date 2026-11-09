# frozen_string_literal: true

module HttpClientGenerator
  module KeyTransformer # :nodoc:
    class CollisionError < StandardError; end

    module_function

    def deep_transform_keys(value, &block)
      case value
      when Hash
        value.each_with_object({}) do |(key, hash_value), transformed|
          assign_key(transformed, yield(key), deep_transform_keys(hash_value, &block))
        end
      when Array
        value.map { |item| deep_transform_keys(item, &block) }
      else
        value
      end
    end

    def assign_key(hash, key, value)
      raise CollisionError, "Key collision: multiple keys map to #{key.inspect}" if hash.key?(key) && hash[key] != value

      hash[key] = value
    end
  end
end
