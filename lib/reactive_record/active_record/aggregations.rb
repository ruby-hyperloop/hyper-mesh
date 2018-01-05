module ActiveRecord

  class Base

    def self.reflect_on_all_aggregations
      # TODO there should be a aggregation hash
      # and this should be @aggregation_hash.keys
      base_class.instance_eval { @aggregations ||= [] }
    end

    def self.reflect_on_aggregation(attribute)
      # TODO this is maybe slow, maybe not
      # instead there should be a hash of aggregations, which may be slow too
      # and the detect replaced by a hash lookup
      reflect_on_all_aggregations.detect { |aggregation| aggregation.attribute == attribute }
    end

  end

  module Aggregations

    class AggregationReflection

      attr_reader :klass_name
      attr_reader :attribute
      attr_reader :mapped_attributes
      attr_reader :constructor

      def construct(args)
        # TODO whats this here?
      end

      def initialize(owner_class, macro, name, options = {})
        owner_class.reflect_on_all_aggregations << self
        @owner_class = owner_class
        @constructor = options[:constructor] || :new
        @klass_name =  options[:class_name] || name.camelize
        @attribute =   name
        if options[:mapping].respond_to? :collect
          @mapped_attributes = options[:mapping].collect &:last
        else
          ReactiveRecord::Base.log("improper aggregate definition #{@owner_class}, :#{name}, class_name: #{@klass_name} - missing mapping", :error)
          @mapped_attributes = []
        end
      end

      def klass
        @klass ||= Object.const_get(@klass_name)
      end

      def serialize(object)
        if object.nil?
          object # return dummy value if that is what we got
        else
          @mapped_attributes.collect { |attr| object.send(attr) }
        end
      end

      def deserialize(array)
        if array.nil?
          array # return dummy value if that is what we got
        elsif @constructor.respond_to?(:call)
          @constructor.call(*array)
        else
          klass.send(@constructor, *array)
        end
      end

    end

  end


end
