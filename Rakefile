# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

default_tasks = %i[spec rubocop]

# The corpus gate exists only once the reviewed goldens are checked in; until
# then script/regenerate_diagnostic_goldens --check has nothing to compare.
if Dir.exist?("spec/fixtures/diagnostics")
  namespace :goldens do
    desc "Verify structured-diagnostic goldens without writing"
    task :check do
      sh "script/regenerate_diagnostic_goldens", "--check"
    end
  end
  default_tasks << "goldens:check"
end

task default: default_tasks
