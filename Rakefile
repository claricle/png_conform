# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

default_tasks = %i[spec rubocop]

# Enable the release gate after the reviewed corpus regeneration.
if Dir.exist?("spec/fixtures/diagnostics")
  namespace :goldens do
    desc "Verify structured-diagnostic goldens without writing"
    task :check do
      ruby "script/regenerate_diagnostic_goldens", "--check"
    end
  end
  default_tasks << "goldens:check"
end

task default: default_tasks
