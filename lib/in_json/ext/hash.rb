module InJson
  module HashExt
    def self.included(base)
      base.send :include, InstanceMethods
    end

    module InstanceMethods
      def recursively_reject(default = nil, &blk)
        inject({}) do |result, k_v|
          key, value = k_v
          result[key] = value.is_a?(Hash) ? value.recursively_reject(&blk) : (value || default)
          result
        end.reject(&blk)
      end
    end
  end
end

Hash.class_eval do
  include InJson::HashExt
end