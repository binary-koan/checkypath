require_relative "generate_route_paths"

module RailsRouteFinder
  class FindRailsRoutes
    attr_reader :filter, :mode

    def initialize(filter: nil, mode: nil)
      @filter = filter
      @mode = mode
    end

    def path_groups
      @path_groups ||= results.map { |result| result[:paths] }.compact
    end

    def warnings
      @warnings ||= results.map { |result| result[:warning] }.compact
    end

    def model_id_generator
      @model_id_generator ||= ModelIdGenerator.new
    end

    def special_paths
      @special_paths ||= SpecialPathHandler.new
    end

    private

    def results
      @results ||= Rails.application.routes.routes.map { |route| GenerateRoutePaths.new(route, self).call }
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
      @resolved_generators = {}
    end

    def on(*models, &handler)
      @generators[models] = handler
    end

    def [](models)
      @resolved_generators[models] ||= @generators[models].call if @generators[models]
    end
  end

  def self.setup(opts)
    @instance = FindRailsRoutes.new(opts)
  end

  def self.path_groups
    @instance.path_groups
  end

  def self.warnings
    @instance.warnings
  end

  def self.generate_model_ids(*models, &handler)
    @instance.model_id_generator.on(*models, &handler)
  end

  def self.handle_special_path(path, &handler)
    @instance.special_paths.on(path, &handler)
  end
end
