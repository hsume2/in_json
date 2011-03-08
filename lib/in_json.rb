require 'in_json/ext/array'

module InJson
  def self.included(base)
    base.extend ClassMethods
    base.send :include, InstanceMethods
  end

  # A {Definition} is a proxy class primarily for evaluating {InJson} blocks into a {Hash} definition.
  #
  #  class Post
  #    in_json do
  #      name
  #      email
  #    end # => {:email=>nil, :name=>nil}
  #
  #    in_json(:with_posts_and_comments_named) do
  #      posts do
  #        title
  #        comments :only_approved
  #      end
  #    end # => {:posts=>{:title=>nil, :comments=>:only_approved}}
  #  end
  class Definition
    def initialize
      @hash = {}
    end

    # Stores any method calls as {Hash} keys
    # @return [Hash] the evaluated definition
    def method_missing(method, *args, &block)
      @hash[method] = block_given? ? Definition.new.instance_eval(&block) : args.first
      @hash
    end
  end

  module ClassMethods
    # Defines an {InJson} definition that can be used to convert an object to JSON format {InJson::InstanceMethods#in_json}
    # @param [Symbol] name the name of the definition
    # @yield a block of definitions
    def in_json(name = :default, &block)
      definitions = read_inheritable_attribute(:in_json_definitions) || {}

      definitions[name] = Definition.new.instance_eval(&block)

      write_inheritable_attribute :in_json_definitions, definitions
    end
  end

  module InstanceMethods
    # Returns a Hash that can be used as this object in JSON format
    # @param [Symbol] name the {InJson} definition to evaluate
    # @param [Symbol, Hash, nil] overrule_definition a named {InJson} definition, a full Hash definition, or nil
    # @return [Hash] the JSON-ready Hash
    def in_json(name = :default, overrule_definition = nil)
      definition = in_json_definition(name, overrule_definition)
      attrs = attributes.freeze.symbolize_keys
      definition.inject({}) do |result, at_dfn|
        at, dfn = at_dfn
        result_at = result[at] = attrs.has_key?(at) ? attrs[at] : send(at)
        result[at] = result_at.map { |entry| entry.in_json(name, dfn) } if result_at && result_at.is_a?(Array)
        result
      end
    end
    alias_method :as_json, :in_json

    protected

    def in_json_definition(name, overrule_definition)
      definitions = self.class.read_inheritable_attribute(:in_json_definitions)

      ( overrule_definition.kind_of?(Symbol) ?
          definitions[overrule_definition] :
          (overrule_definition || definitions[name])
      ) || definitions[:default]
    end
  end
end

ActiveRecord::Base.class_eval { include InJson }