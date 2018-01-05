module ReactiveRecord
  module Proxy
    class RootNode < BasicObject
      def initialize(model_name, acting_user)
        # 1. step: check legality of model
        raise unless ActiveRecord::Base.public_columns_hash.has_key?(model_name)
        # 2. step: check policy
        # TODO
        @model = model_name.constantize
        @acting_user = acting_user
      end

      # BasicObject defines instance_eval and -exec, need to overwrite those here
      def instance_eval; Hyperloop::InternalPolicy.raise_access_violation; end
      def instance_exec; Hyperloop::InternalPolicy.raise_access_violation; end

      def method_missing(name, args)
        # 3. step, check method legality
        Hyperloop::InternalPolicy.gurd_root_fetch_method!(@model, method)
        # 4. step, call method
        result = @model.send(method, args)
        # 5. step, wrap result in proxy
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