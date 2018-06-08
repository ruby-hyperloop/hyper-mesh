class Rematerialize

  class Model

    def self.load(models, saving)
      hash = {}
      models.each { |model| new(model, hash, saving) }
      hash
    end

    def initialize(client_model_rep, hash, saving)
      @client_model_rep = client_model_rep
      @saving = saving
      hash[rr_id] = self
      dont_save! if new? && !saving
      load_attributes
    end

    def new?
      @new = !!(record && (!record.respond_to?(:id) || !record.id)) if @new.nil?
      @new
    end

    def dont_save!
      @dont_save = true
    end

    def save!
      @dont_save = false
    end

    def dont_save?
      @dont_save
    end

    def enum?(key)
      record.class.respond_to?(:defined_enums) && record.class.defined_enums[key]
    end

    def load_attributes
      keys = record.attributes.keys
      attributes.each do |key, value|
        if enum?(key)
          record.send("#{key}=", value)
        elsif keys.include? key
          record[key] = value
        elsif value && (aggregation = record.class.reflect_on_aggregation(key.to_sym)) && !(aggregation.klass < ActiveRecord::Base)
          aggregation.mapping.each_with_index do |pair, i|
            record[pair.first] = value[i]
          end
        elsif record.respond_to? "#{key}="
          record.send("#{key}=", value)
        else
          # TODO once reading schema.rb on client is implemented throw an error here
        end
      end
    end

    def vector
      @vector ||= begin
        vector = @client_model_rep[:vector]
        [vector[0].constantize] + vector[1..-1].collect do |method|
          if method.is_a?(Array) && (method.first == "find_by_id")
            ["find", method.last]
          else
            method
          end
        end
      end
    end

    def attributes
      @attributes ||= @client_model_rep[:attributes]
    end

    def model
      @model ||= Object.const_get(@client_model_rep[:model])
    end

    def method_missing(name, *args, &block)
      if record.respond_to? name
        record.send(name, *args, &block)
      else
        super
      end
    end

    def id
      @id ||= attributes.delete(model.primary_key) if model.respond_to? :primary_key
    end

    def rr_id
      @rr_id ||= @client_model_rep[:id]
    end

    attr_reader :messages

    def record
      @record ||=
        if !@saving
          found = vector[1..-1].inject(vector[0]) do |object, method|
            if object.nil? # happens if you try to do an all on empty scope followed by more scopes
              object
            elsif method.is_a? Array
              if method[0] == 'new'
                object.new
              else
                object.send(*method)
              end
            elsif method.is_a? String and method[0] == '*'
              object[method.gsub(/^\*/,'').to_i]
            else
              object.send(method)
            end
          end
          if id and (found.nil? or !(found.class <= model) or (found.id and found.id.to_s != id.to_s))
            raise "Inconsistent data sent to server - #{model.name}.find(#{id}) != [#{vector}]"
          end
          found
        elsif id
          model.find(id)
        else
          model.new
        end
    end

    def validate
      @messages = errors.messages if !valid?
    end

    def response_array
      [rr_id, model.name, __hyperloop_secure_attributes(@acting_user), @messages]
    end

    %w[aggregation, association].each do |relation_type|
      define_method(:"reflect_on_#{relation_type}") do |attr|
        model.send("reflect_on_#{relation_type}", attr.to_sym)
      end
    end
  end

  def initialize(models, associations, acting_user, validate, save)
    @models = Model.load(models, save)
    @vectors = @models.values.collect { |model| model.vector }
    @associations = associations || []
    @acting_user = acting_user
    @validate = validate
    @save = save
  end

  def load_aggregate(parent, aggregate, attribute)
    aggregate.dont_save!
    current_attributes = parent.record.send(attribute).attributes
    new_attributes = aggregate.record.attributes
    merged_attributes = current_attributes.merge(new_attributes) do |k, current_attr, new_attr|
      aggregate.record.send("#{k}_changed?") ? new_attr : current_attr
    end
    aggregate.record.assign_attributes(merged_attributes)
    parent.record.send("#{attribute}=", aggregate)
  end

  def load_association(parent, child_id, reflection, attr)
    parent.save!
    if !reflection
      raise "Missing association :#{association[:attribute]} for #{parent.model.name}.  Was association defined on opal side only?"
    elsif !relection.collection?
      parent.record.send("#{attr}=", @models[child_id])
    end
  end

  def load_associations
    @associations.each do |assoc|
      next unless (parent = @models[assoc[:parent_id]])
      if parent.reflect_on_aggregation(assoc[:attribute])
        load_aggregate parent, @models[assoc[:child_id]], assoc[:attribute]
      else
        reflection = parent.reflect_on_association(assoc[:attribute])
        load_association parent, @models[assoc[:child_id]], reflection, assoc[:attribute]
      end
    end
  end

  def filter_and_save_models
    @models.keep_if do |rr_id, model|
      next false unless model # throw out items where we couldn't find a record
      next true  if model.frozen?  # skip (but process later) frozen records
      next true  if model.dont_save? # skip if the record is on the don't save list
      next true  if model.changed.include?(record.class.primary_key)  # happens on an aggregate
      next false if model.id && !model.changed? # throw out any existing records with no changes
      # if we get to here save the record and return true to keep it
      op = model.new? ? :create_permitted? : :update_permitted?
      model.check_permission_with_acting_user(@acting_user, op).save(validate: false) || true
    end
  end

  def response
    @models.values.collect { |model| model.response_array }
  end

  def log_validation_errors
    messages = @models.values.collect do |model|
      model.messages.collect do |message|
        ::Rails.logger.debug "\033[0;31;1m\t#{model}: #{message}\033[0;30;21m"
      end if messages
    end.compact
    return false if messages.empty?
    ::Rails.logger.debug "\033[0;31;1mERROR: HyperModel saving records failed:\033[0;30;21m"
    messages.each { |str| ::Rails.logger.debug str }
    @failed = true
  end

  def run
    ActiveRecord::Base.transaction do
      load_associations
      filter_and_save_models
      return @vectors unless @save || @validate

      # otherwise either save or validate or both are true, so we convert the remaining react_records into
      # arrays with the id, model name, legal attributes, and any error messages.  We also accumulate
      # the all the error messages during a save so we can dump them to the server log.

      @models.values.each { |model| model.validate } if @validate

      # if we are not saving (i.e. just validating) then we rollback the transaction

      raise ActiveRecord::Rollback, 'This Rollback is intentional!' unless @save

      # if there are error messages then we dump them to the server log, and raise an error
      # to roll back the transaction and set success to false.
      raise ActiveRecord::Rollback, 'This Rollback is intentional!' if log_validation_errors

    end

    { success: !@failed, saved_models: response }

  rescue Exception => e
    if @save || @validate
      {success: false, saved_models: response, message: e}
    else
      {}
    end
  end
end
