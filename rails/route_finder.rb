module RailsRouteFinder
  class FindRailsRoutes
    attr_reader :filter, :mode

    def initialize(filter: nil, mode: nil)
      @filter = filter
      @mode = mode
    end

    def routes
      Rails.application.routes.routes
        .flat_map { |route| GenerateRoutePaths.new(route).call }
        .uniq.sort.join("\n")
    end

    def model_id_generator
      @model_id_generator ||= ModelIdGenerator.new
    end

    def special_paths
      @special_paths ||= SpecialPathHandler.new
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

  def setup(opts)
    @instance = FindRailsRoutes.new(opts)
  end

  def routes
    @instance.routes
  end

  def model_ids_for(*models, &handler)
    @instance.model_id_generator.on(*models, &handler)
  end

  def special_path(path, &handler)
    @instance.special_paths.on(path, &handler)
  end
end
