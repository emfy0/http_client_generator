# frozen_string_literal: true

module HttpClientGenerator
  class ResourcesDefinition
    attr_reader :resources

    DEFAULT_OPTIONS = {
      content_type: :json
    }.freeze

    HTTP_VERBS = %i[get post put patch].freeze

    def initialize(base, req_plugs = [], resp_plugs = [])
      @base = base
      @resources = []
      @req_plugs = req_plugs
      @resp_plugs = resp_plugs
    end

    HTTP_VERBS.each do |verb|
      define_method(verb) do |name, **options|
        @resources << build_resource(verb, name, options)
      end
    end

    def req_plug(plug, *args, **kwargs)
      @req_plugs << build_plug(plug, *args, **kwargs)
    end

    def resp_plug(plug, *args, **kwargs)
      @resp_plugs << build_plug(plug, *args, **kwargs)
    end

    def namespace(_name, &block)
      namespaced_definition = ResourcesDefinition.new(@base, @req_plugs.dup, @resp_plugs.dup)
      namespaced_definition.instance_eval(&block)
      @resources += namespaced_definition.resources
    end

    private

    def build_plug(plug, *args, **kwargs)
      if plug.respond_to?(:call)
        plug
      elsif plug.respond_to?(:new)
        plug.new(*args, **kwargs)
      else
        Plugs.read(plug).new(*args, **kwargs)
      end
    end

    def build_resource(verb, name, options)
      Resource.new(
        verb: verb,
        name: name,
        base: @base,
        req_plugs: @req_plugs,
        resp_plugs: @resp_plugs,
        **with_defaults(options)
      )
    end

    def with_defaults(options)
      DEFAULT_OPTIONS.merge(options)
    end
  end
end
