# frozen_string_literal: true

require 'singleton'

module HttpClientGenerator
  class Plugs
    include Singleton

    def self.register(key, plug)
      instance.register(key, plug)
    end

    def self.read(key)
      unless key.is_a?(Symbol)
        raise "Expected symbol got #{key.inspect}"
      end

      instance.read(key)
    end

    def register(key, plug)
      storage[key] = plug
    end

    def read(key)
      storage[key]
    end

    private

    def storage
      @storage ||= {}
    end
  end
end
