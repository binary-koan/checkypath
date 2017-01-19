require "rails/console/app"
require_relative "generate_route_paths"

module RailsRouteFinder
  class << self
    include Rails::ConsoleMethods

    attr_accessor :options

    def on_paths(&handler)
      @on_paths ||= []
      @on_paths << handler
    end

    def on_warning(&handler)
      @on_warning ||= []
      @on_warning << handler
    end

    def find_paths
      paths = []
      warnings = []

      Rails.application.routes.routes.each do |route|
        result = GenerateRoutePaths.new(route, options.filter).call

        if result[:paths]
          paths += result[:paths]
          @on_paths.each { |handler| handler.call(result[:paths]) }
        elsif result[:warning]
          warnings << result[:warning]
          @on_warning.each { |handler| handler.call(result[:warning]) }
        end
      end

      yield paths, warnings
    end
  end
end
