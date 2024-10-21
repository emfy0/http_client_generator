# frozen_string_literal: true

module HttpClientGenerator
  module UrlBuilder
    def self.included(base)
      super

      base.extend(self)
      base.extend(base)
    end

    def url_for(name, &block)
      define_singleton_method(name, &block)
      define_method(name, &block)
    end
  end
end
