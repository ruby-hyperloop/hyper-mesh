module Hyperloop
  class InternalPolicy
    VALID_HYPER_ROOT_FETCH_METHODS = %i[find find_by unscoped]
    VALID_HYPER_RECORD_FETCH_METHODS = %i[*all]
    VALID_HYPER_RELATION_FETCH_METHODS = %i[all count]

    def self.accessible_attributes_for(model, acting_user)
      user_channels = ClassConnectionRegulation.connections_for(acting_user, false) +
        InstanceConnectionRegulation.connections_for(acting_user, false)
      internal_policy = InternalPolicy.new(model, model.attribute_names, user_channels)
      ChannelBroadcastRegulation.broadcast(internal_policy)
      InstanceBroadcastRegulation.broadcast(model, internal_policy)
      internal_policy.accessible_attributes_for
    end

    def accessible_attributes_for
      accessible_attributes = Set.new
      @channel_sets.each do |channel, attribute_set|
        accessible_attributes.merge attribute_set
      end
      accessible_attributes << :id unless accessible_attributes.empty?
      accessible_attributes
    end

    def self.guard_root_fetch_method!(model, method)
      method = method.to_sym
      return true if VALID_HYPER_RECORD_FETCH_METHODS.include?(method) # array of symbols
      return true if model.hyper_model_scopes.include?(method) # array of symbols
      raise_access_violation
    end

    def self.guard_record_fetch_method!(record, method)
      return true if record.attribute_names.include?(method) # array of strings
      method = method.to_sym
      return true if VALID_HYPER_RECORD_FETCH_METHODS.include?(method) # array of symbols
      return true if record.class.reflect_on_association(method) # symbol
      return true if record.class.hyper_model_scopes.include?(method) # array of symbols
      return true if model.class.server_methods.include?(method) # array of symbols
      raise_access_violation
    end

    def self.guard_relation_fetch_method!(relation, method)
      method = method.to_sym
      return true if VALID_HYPER_RELATION_FETCH_METHODS.include?(method)
      raise_access_violation
    end
  end
end