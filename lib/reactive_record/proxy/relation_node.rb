module ReactiveRecord
  module Proxy
    class RelationNode < BasicObject
      def initialize(relation, acting_user)
        @relation = relation
        @acting_user = acting_user
      end

      # BasicObject defines instance_eval and -exec, need to overwrite those here
      def instance_eval; Hyperloop::InternalPolicy.raise_access_violation; end
      def instance_exec; Hyperloop::InternalPolicy.raise_access_violation; end

      def method_missing(name, args)
        # 2. step, check method legality
        Hyperloop::InternalPolicy.guard_relation_fetch_method!(@model, method)
        # 3. step, call method
        result = @relation.send(method, args)
        # 4. step, wrap result in proxy
        # a relation ca only have another relation as result or a model
        if result < ActiveRecord::Base
          ReactiveRecord::Proxy::RecordNode.new(result, @acting_user)
        elsif result < ActiveRecord::Relation
          ReactiveRecord::Proxy::RelationNode.new(result, @acting_user)
        else
          Hyperloop::InternalPolicy.raise_access_violation
        end
      end
    end
  end
end