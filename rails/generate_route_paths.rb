require_relative "route_transformers"

class GenerateRoutePaths
  include RouteTransformers

  class ModelNotFound < StandardError; end

  def self.all_models
    @all_models ||= ActiveRecord::Base.connection.tables.map { |table| model_for_table(table) }.compact.to_h
  end

  def self.model_for_table(table)
    [table.classify, table.classify.constantize]
  rescue NameError => e
    nil
  end

  attr_reader :route, :filter

  def initialize(route, filter)
    @route = route
    @filter = filter
  end

  def call
    result = preliminary_result

    if result[:paths]
      validate_paths(result)
    else
      result
    end
  end

  private

  def preliminary_result
    if !path.include?(filter)
      {}
    elsif route.verb !~ 'GET'
      RailsRouteFinder.options.verbose ? warning("Not a GET route: #{path}") : {}
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

  def validate_paths(result)
    response_code = RailsRouteFinder.app.get result[:paths].first

    if response_code >= 400
      RailsRouteFinder.options.verbose ? warning("Ignoring route with #{response_code} response code: #{path}") : {}
    elsif response_code == 302 && fail_on_redirect_paths.any? { |path| app.response.redirect_url.end_with?(path) }
      raise "Critical error: A route redirected to the failure path #{app.response.redirect_url}"
    else
      # Looks OK, pass the result on
      result
    end
  end

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
