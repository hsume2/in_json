require 'in_json/ext/array'
require 'in_json/ext/hash'

module InJson
  def self.included(base)
    base.extend ClassMethods
    base.send :include, InstanceMethods
  end

  def self.with(name = :default, &block)
    begin
      Thread.current[:in_json_definition] = name
      yield
    ensure
      Thread.current[:in_json_definition] = nil
    end
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
      method_s = method.to_s
      method = method_s.sub(/^_/, '').to_sym if method_s =~ /^_.*/
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

    # Calculates associations to be load alongside based on an {InJson} definition
    # @param [Symbol] name the definition to calculate from
    # @return [Hash] the associations
    def include_in_json(name = :default)
      definitions = read_inheritable_attribute(:in_json_definitions) || {}
      definition = definitions[name]
      return unless definition
      definition.recursively_reject { |key, value| value.nil? }
    end
  end

  module InstanceMethods
    # Returns a Hash that can be used as this object in JSON format
    # @param [Symbol] name the {InJson} definition to evaluate
    # @param [Symbol, Hash, nil] injected_definition a named {InJson} definition, a full Hash definition, or nil
    # @return [Hash] the JSON-ready Hash
    def in_json(name = :default, injected_definition = nil)
      definition = in_json_definition(name, injected_definition)
      attrs = attributes.freeze.symbolize_keys
      return attrs unless definition
      definition.inject({}) do |result, attr_dfn|
        attr, definition = attr_dfn

        result_at = attrs.has_key?(attr) ? attrs[attr] : send(attr)
        result_at = result_at.in_json(name, definition) if result_at.respond_to?(:in_json) && !result_at.kind_of?(Class)

        result[attr] = result_at
        result
      end
    end
    alias_method :as_json, :in_json

    protected

    # TODO move precedence to doc
    def in_json_definition(name, injected_definition)
      definitions = self.class.read_inheritable_attribute(:in_json_definitions)

      # Try nested first (if I am nested)
      return injected_definition if injected_definition.kind_of?(Hash)

      # Try named second
      injected_definition.kind_of?(Symbol) && definitions && result = definitions[injected_definition]
      return result if result

      # Try thread third
      thread_definition = Thread.current[:in_json_definition]
      thread_definition && definitions && result = definitions[thread_definition]
      return result if result # *yuck*

      # Try given definitions fourth
      definitions && result = definitions[name]
      return result if result

      # Try default last
      return definitions && definitions[:default]
    end
  end
end

ActiveRecord::Base.class_eval { include InJson }