# frozen_string_literal: true

module HttpClientGenerator
  module TimeoutNormalizer # :nodoc:
    VALID_KEYS = %i[connect read write].freeze

    ERROR_MESSAGE = 'Use timeout(global), timeout(:null), or timeout(connect: x, read: y, write: z).'

    def self.call(value = nil, **options)
      timeout_value = build_timeout_value(value, options)
      case timeout_value
      when Numeric, :null
        timeout_value
      when Hash
        normalize_hash(timeout_value)
      else
        raise ArgumentError, ERROR_MESSAGE
      end
    end

    def self.build_timeout_value(value, options)
      if options.any?
        raise ArgumentError, ERROR_MESSAGE unless value.nil?

        options
      else
        value
      end
    end
    private_class_method :build_timeout_value

    def self.normalize_hash(timeout_value)
      invalid_keys = timeout_value.keys - VALID_KEYS

      raise ArgumentError, "Unknown timeout option(s): #{invalid_keys.join(', ')}." if invalid_keys.any?

      timeout_value.dup
    end
    private_class_method :normalize_hash
  end
end
