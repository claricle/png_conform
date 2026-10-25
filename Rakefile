# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

namespace :diagnostics do
  desc "Verify checked-in diagnostics goldens without writing files"
  task :check do
    ruby "script/regenerate_diagnostic_goldens", "--check"
  end
end

namespace :goldens do
  desc "Verify structured-diagnostic goldens without writing"
  task check: "diagnostics:check"
end

task default: %i[spec rubocop diagnostics:check]
