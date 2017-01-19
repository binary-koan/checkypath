require "pathname"
require "optparse"
require "ostruct"

require_relative "rails_route_finder"

RailsRouteFinder.options = OpenStruct.new(output: "routes.txt")
load_file = ARGV.shift

OptionParser.new do |opts|
  opts.on("-m", "--mode [MODE]", "Switch modes as defined in the helper file") do |mode|
    RailsRouteFinder.options.mode = mode
  end

  opts.on("-f", "--filter [FILTER]", "Only output routes containing the filter string") do |filter|
    RailsRouteFinder.options.filter = filter
  end

  opts.on("-o", "--output [FILE]", "Output will be stored in this file (default: routes.txt)") do |filename|
    RailsRouteFinder.options.output = filename
  end

  opts.on("-v", "--[no-]verbose", "Print more debugging shizz") do |verbose|
    RailsRouteFinder.options.verbose = verbose
  end
end.parse!

require Pathname.new(load_file).realpath.to_s

RailsRouteFinder.on_paths { |paths| print "." * paths.size }
RailsRouteFinder.on_warning { print "x" if RailsRouteFinder.options.verbose }

RailsRouteFinder.find_paths do |paths, warnings|
  File.open(RailsRouteFinder.options.output, "w") do |f|
    f.puts(warnings.sort.join("\n"))
    f.puts(paths.sort.join("\n"))
  end

  puts
  puts "#{paths.size} paths, #{warnings.size} warnings."
end
