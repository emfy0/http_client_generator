# frozen_string_literal: true

module HttpClientGenerator
  class ResourcesDefinition # :nodoc:
    attr_reader :resources

    DEFAULT_OPTIONS = {
      content_type: :json
    }.freeze

    HTTP_VERBS = %i[get post put patch].freeze

    def initialize(base, req_plugs = [], response_plugs = {}, timeout = nil)
      @base = base
      @resources = []
      @req_plugs = req_plugs
      @resp_head_plugs = response_plugs.fetch(:head, [])
      @resp_plugs = response_plugs.fetch(:body, [])
      @timeout = timeout
    end

    HTTP_VERBS.each do |verb|
      define_method(verb) do |name, **options|
        @resources << build_resource(verb, name, options)
      end
    end

    def req_plug(plug, *args, only: nil, except: nil, **kwargs)
      @req_plugs << build_plug_entry(plug, *args, only: only, except: except, **kwargs)
    end

    def resp_plug(plug, *args, only: nil, except: nil, **kwargs)
      @resp_plugs << build_plug_entry(plug, *args, only: only, except: except, **kwargs)
    end

    def resp_head_plug(plug, *args, only: nil, except: nil, **kwargs)
      @resp_head_plugs << build_plug_entry(plug, *args, only: only, except: except, **kwargs)
    end

    def timeout(value = nil, **options)
      @timeout = TimeoutNormalizer.call(value, **options)
    end

    def namespace(_name = nil, &block)
      namespaced_definition = ResourcesDefinition.new(
        @base, @req_plugs.dup, { head: @resp_head_plugs.dup, body: @resp_plugs.dup }, @timeout
      )
      namespaced_definition.instance_eval(&block)
      @resources += namespaced_definition.resources
    end

    private

    def build_plug_entry(plug, *args, only:, except:, **kwargs)
      {
        plug: build_plug(plug, *args, **kwargs),
        only: Array(only).compact.uniq.map(&:to_sym),
        except: Array(except).compact.uniq.map(&:to_sym)
      }
    end

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
      resource_options = with_defaults(options)

      Resource.new(
        verb: verb,
        name: name,
        base: @base,
        req_plugs: @req_plugs,
        resp_head_plugs: @resp_head_plugs,
        resp_plugs: @resp_plugs,
        **resource_options
      )
    end

    def with_defaults(options)
      resource_options = DEFAULT_OPTIONS.merge(options)
      resource_options[:timeout] =
        if options.key?(:timeout)
          TimeoutNormalizer.call(options[:timeout])
        else
          @timeout
        end

      resource_options
    end
  end
end
