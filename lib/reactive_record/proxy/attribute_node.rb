# The general idea is, to use "empty" proxy objects as guards to ActiveRecord classes
# and objects, to ensure that only a allowed subset of methods is called on them.
# No methods are added to the objects, instead existing methods overwritten to raise
# an exception. Every other method call must go through method_missing.
# method_missing is then used to check if the method call is allowed and
# wraps the result in another proxy. This way the complete chain of calls is guarded.
# Only AttributeNode adds a value getter.

# TODO limit call chain length/graph depth

module ReactiveRecord
  module Proxy
    class AttributeNode < BasicObject
      # method to retrieve value
      def value(rails_object = nil)
        # The assumption here is, that the Rails object cannot be passed serialized
        # over the internets, instead its a object existing in current Rails context only.
        # Testing if the as param passed Rails object and the ::Rails object are equal,
        # its ensured, that the call is made locally only. This prevents method chaining
        # on the @value of the AttributeNode over JSON.
        # Any "Rails" coming in as param over JSON will be a String, thus != ::Rails, and will raise.
        # The default param nil ensures the access_violation is raised if no param is passed.
        # From the internets this value method will always raise and exhibit the same behaviour
        # as the method missing below.
        # Only local calls will get through with the Rails object passed as param and allow
        # the retrieval of @value. 
        # This is necessary, as otherwise the door would be open, for eaxample, if @value is a 
        # String "busted", to call "busted".instance_eval("`ls -lR`") over JSON.
        Hyperloop::InternalPolicy.raise_access_violation unless ::Rails == rails_object
        @value
      end

      def initalize(record, attribute, value)
        Hyperloop::InternalPolicy.raise_access_violation unless record.view_permitted?(attribute)
        @value = value
      end

      # BasicObject defines instance_eval and -exec, need to overwrite those here
      def instance_eval; Hyperloop::InternalPolicy.raise_access_violation; end
      def instance_exec; Hyperloop::InternalPolicy.raise_access_violation; end

      # no method calls allowed on AttributeNodes
      def method_missing; Hyperloop::InternalPolicy.raise_access_violation; end
    end
  end
end