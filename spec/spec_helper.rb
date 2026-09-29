# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  cover "**/*.rb"
  enable_coverage :branch
  skip "/config/"
  skip "/spec/"
  skip "/tmp/"

  group "lib/blog", "lib/blog/"
  Dir.children(File.join(root, "slices")).sort.each do |slice|
    group(slice) do |file|
      file.filename.start_with?(File.join(root, "slices", slice, ""), File.join(root, "lib", slice, ""))
    end
  end
end

support_path = File.expand_path("support", File.dirname(__FILE__))

require File.join(support_path, "stdout")

ENV["HANAMI_ENV"] ||= "test"
require "hanami/prepare"
require "rspec/collection_matchers"

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "log/spec_examples.txt"
  config.default_formatter = "doc" if config.files_to_run.one?
  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed
end

Dir.glob(File.join(support_path, "**/*.rb")).each { |file| require file }
