require "pathname"
require "optparse"

require_relative "rails_route_finder"

options = { filter: nil, mode: nil }
load_file = ARGV.shift

OptionParser.new do |opts|
  opts.on("-m", "--mode [MODE]", "Switch modes as defined in the helper file") do |mode|
    options[:mode] = mode
  end

  opts.on("-f", "--filter [FILTER]", "Only output routes containing the filter string") do |filter|
    options[:filter] = filter
  end
end.parse!

RailsRouteFinder.setup(options)

require Pathname.new(load_file).realpath.to_s
require "rails/console/app"

include Rails::ConsoleMethods

require "pry-byebug"
binding.pry

puts RailsRouteFinder.warnings.sort.join("\n")
puts RailsRouteFinder.path_groups.flatten.uniq.sort.join("\n")
