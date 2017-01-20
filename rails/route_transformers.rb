module RouteTransformers
  def self.included(base)
    base.extend(ClassMethods)
  end

  def model_id_generator
    self.class.model_id_generator
  end

  def special_paths
    self.class.special_paths
  end

  def path_validators
    self.class.path_validators
  end

  def fail_on_redirect_paths
    self.class.fail_on_redirect_paths || []
  end

  module ClassMethods
    attr_reader :path_validators, :fail_on_redirect_paths

    def model_id_generator
      @model_id_generator ||= ModelIdGenerator.new
    end

    def special_paths
      @special_paths ||= SpecialPathHandler.new
    end

    def validate_paths(&validator)
      @path_validators ||= []
      @path_validators << validator
    end

    def fail_on_redirect_to(path, except: [])
      @fail_on_redirect_paths ||= []
      @fail_on_redirect_paths << { :path => path, :except => except }
    end
  end

  class SpecialPathHandler
    def initialize
      @handlers = {}
    end

    def on(path, &handler)
      @handlers[path] = handler
    end

    def [](path)
      @handlers[path].call if @handlers[path]
    end
  end

  class ModelIdGenerator
    def initialize
      @generators = {}
      @fallbacks = {}
      @resolved_generators = {}
    end

    def on(*models, &handler)
      @generators[models] = handler
    end

    def attempt_fallback(model, &handler)
      @fallbacks[model] = handler
    end

    def [](models)
      return @resolved_generators[models] if @resolved_generators[models]

      if @generators[models]
        @resolved_generators[models] = @generators[models].call
      elsif @fallbacks[models.first]
        @resolved_generators[models] = @fallbacks[models.first].call(models[1..-1])
      end
    end
  end
end
