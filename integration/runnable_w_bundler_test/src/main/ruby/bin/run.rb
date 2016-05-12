require 'bundler/setup'

path = File.join(Gem.loaded_specs['json'].full_gem_path, 'lib')
File.open(ARGV[2], 'w') do |f|
  f.puts("hello world")
  f.puts path
  f.puts $LOAD_PATH
end

unless $LOAD_PATH.member? path
  raise "wrong load path, expected #{path} to be in #{$LOAD_PATH}"
end

$LOAD_PATH.each do |p|
  unless p =~ /^uri:classloader:/
    raise "expected path #{p} to start with uri:classloader:"
  end
end
