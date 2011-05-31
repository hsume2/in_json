module InJson
  module HashExt
    def self.included(base)
      base.send :include, InstanceMethods
    end

    module InstanceMethods
      def recursively_reject(&blk)
        reject(&blk).inject({}) do |result, k_v|
          key, value = k_v
          result[key] = value.is_a?(Hash) ? value.recursively_reject(&blk) : value
          result
        end
      end
    end
  end
end

Hash.class_eval do
  include InJson::HashExt
end