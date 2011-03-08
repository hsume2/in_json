module InJson
  module ArrayExt
    def self.included(base)
      base.send :include, InstanceMethods
    end

    module InstanceMethods
      def in_json(name = :default, overrule_definition = nil)
        map { |entry| entry.in_json(name, overrule_definition) }
      end
    end
  end
end

Array.class_eval do
  include InJson::ArrayExt
end