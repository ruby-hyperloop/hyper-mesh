module ReactiveRecord
  module Proxy
    class RecordNode < BasicObject
      def initialize(record, acting_user)
        # 1. step: check legality of record
        raise unless ActiveRecord::Base.public_columns_hash.has_key?(record.model_name)
        @record = record
        @acting_user = acting_user
      end

      # BasicObject defines instance_eval and -exec, need to overwrite those here
      def instance_eval; Hyperloop::InternalPolicy.raise_access_violation; end
      def instance_exec; Hyperloop::InternalPolicy.raise_access_violation; end

      def method_missing(name, args)
        # 2. step, check method legality
        Hyperloop::InternalPolicy.guard_record_fetch_method!(@record, method)
        # 3. step, call method
        result = @record.send(method, args)
        # 4. step, wrap result in proxy
        if result < ActiveRecord::Base
          ReactiveRecord::Proxy::RecordNode.new(result, @acting_user)
        elsif result < ActiveRecord::Relation
          ReactiveRecord::Proxy::RelationNode.new(result, @acting_user)
        else
          ReactiveRecord::Proxy::AttributeNode.new(record, method, result)
        end
      end
    end
  end
end