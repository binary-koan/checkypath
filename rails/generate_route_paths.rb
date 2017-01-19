class GenerateRoutePaths
  class ModelNotFound < StandardError; end

  def self.all_models
    @all_models ||= ActiveRecord::Base.connection.tables.map { |table| model_for_table(table) }.compact.to_h
  end

  def self.model_for_table(table)
    [table.classify, table.classify.constantize]
  rescue NameError => e
    nil
  end

  attr_reader :route, :filter, :model_id_generator, :special_paths

  def initialize(route, route_finder)
    @route = route
    @filter = route_finder.filter
    @model_id_generator = route_finder.model_id_generator
    @special_paths = route_finder.special_paths
  end

  def call
    if route.verb !~ 'GET' || !path.include?(filter)
      {}
    elsif special_paths[path]
      paths(special_paths[path])
    elsif path_parameters.empty?
      paths([path])
    elsif non_id_path_parameter?
      warning("Can't parse parameters")
    else
      handle_path_with_ids
    end
  end

  private

  def non_id_path_parameter?
    path_parameters.any? { |param| param !~ /id\z/ }
  end

  def handle_path_with_ids
    models = find_models(path)

    if (id_sets = model_id_generator[models])
      paths(id_sets.map { |ids| path_with_parameters(ids) })
    else
      warning("No handler for models #{models.join(", ")}")
    end
  rescue ModelNotFound => e
    warning(e.message)
  end

  def find_models(path)
    previous_parts = []
    discovered_models = []

    path_parts.each do |part|
      if part == ':id'
        discovered_models << find_model(previous_parts)
        raise ModelNotFound, "Can't find a model name in: #{previous_parts.join("/")}" if discovered_models.last.nil?
      elsif part =~ /:([a-z_]+)_id/
        discovered_models << find_model([$1])
        raise ModelNotFound, "ID parameter doesn't correspond to a model: #{$1}" if discovered_models.last.nil?
      else
        previous_parts << part
      end
    end

    discovered_models
  rescue NameError => e
    raise ModelNotFound, "Couldn't find model: #{e.message}"
  end

  def find_model(name_options)
    name_options.map { |name| self.class.all_models[name.singularize.classify] }.compact.last
  end

  def path_with_parameters(parameters)
    parameters = parameters.dup
    path_parts.map { |part| path_parameter?(part) ? parameters.shift : part }.join("/")
  end

  def path_parameters
    path_parts.select { |part| path_parameter?(part) }
  end

  def path_parameter?(part)
    part =~ /\A:[a-z_]+\z/
  end

  def path_parts
    path.split("/")
  end

  def path
    @path ||= route.path.spec.to_s.sub(/\(\.:format\)$/, "")
  end

  def warning(message)
    { :warning => "# WARNING: #{message} (from #{path})" }
  end

  def paths(paths)
    { :paths => paths }
  end
end
