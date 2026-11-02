# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

namespace :golden_reports do
  desc "Regenerate YAML and JSON reporter goldens (review byte changes before committing)"
  task :regenerate do
    sh({ "REGENERATE_REPORT_GOLDENS" => "1" }, "bundle", "exec", "rspec",
       "spec/png_conform/golden_reports_spec.rb")
  end
end

namespace :diagnostics do
  desc "Verify checked-in diagnostics goldens without writing files"
  task :check do
    ruby "script/regenerate_diagnostic_goldens", "--check"
  end
end

task default: %i[spec rubocop diagnostics:check]
