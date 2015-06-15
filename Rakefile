# encoding: utf-8
task :console do
    require 'pry'
    require_relative 'lib/λ'
    include Lambda

    Signal.trap("ABRT") do
        puts caller[0..10].join("\n")
    end

    ARGV.clear
    Pry::CLI.parse_options
end
