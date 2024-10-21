# frozen_string_literal: true

module HttpClientGenerator
  module SchemaBuilder
    def self.included(base)
      super

      require 'datacaster'
      base.extend(self)
    end

    def schema_for(name, kind: :choosy, &block)
      @schemas ||= {}
      @schemas[name] =
        case kind
        in :choosy
          Datacaster.choosy_schema(&block)
        in :partial
          Datacaster.partial_schema(&block)
        in :strict
          Datacaster.schema(&block)
        end

      define_singleton_method(name) do |params|
        @schemas[name].(params)
      end

      define_method(name) do |params|
        @schemas[name].(params)
      end
    end
  end
end
