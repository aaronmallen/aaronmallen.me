# frozen_string_literal: true

require "rom-factory"

module ROM
  module Factory
    class Factories
      module Tagging
        def create(name, *traits, **attrs)
          Spec::DB::Tagging.call(name, super(name, *traits, **attrs.except(:tags)), attrs[:tags])
        end
      end

      module Linking
        def create(name, *traits, **attrs)
          super(name, *traits, **Spec::DB::Linking.call(name, attrs))
        end
      end

      prepend Linking
      prepend Tagging
    end
  end
end

module Spec
  module DB
    module Factories
      STRUCT_MODULE_NAME = :Structs

      class << self
        def [](slice_name = nil)
          registry.fetch((slice_name || Hanami.app.slice_name).to_sym)
        end

        def create(name, ...) = for_factory(name).create(name, ...)

        def define(...)
          (@defining || self[]).define(...)
        end

        def for_factory(name, slice_name = nil)
          return self[slice_name] if slice_name

          registry.each_value.find { it.registry.key?(name) } || self[]
        end

        private

        def build(slice)
          ROM::Factory
            .configure(slice.slice_name.namespace_name) { |config| config.rom = slice["db.rom"] }
            .struct_namespace(struct_namespace(slice))
        end

        def definitions_root(slice)
          root = Hanami.app.root.join("spec")

          return root.join("factories") if slice.eql?(Hanami.app)

          root.join("slices", slice.slice_name.to_s, "factories")
        end

        def load_definitions(slice)
          @defining = self[slice.slice_name]
          Dir[definitions_root(slice).join("**", "*.rb")].each { require it }
        ensure
          @defining = nil
        end

        def registry
          return @registry if defined?(@registry)

          @registry = {}

          Hanami.app.with_slices.each do |slice|
            next unless slice.key?("db.rom")

            @registry[slice.slice_name.to_sym] = build(slice)
            load_definitions(slice)
          end

          @registry
        end

        def struct_namespace(slice)
          namespace = slice.namespace

          if namespace.const_defined?(STRUCT_MODULE_NAME)
            namespace.const_get(STRUCT_MODULE_NAME)
          else
            namespace.const_set(STRUCT_MODULE_NAME, Module.new)
          end
        end
      end
    end

    module Linking
      KEYS = { oauth_token: %i[oauth_client], webmention: %i[post] }.freeze

      def self.call(name, attrs)
        KEYS.fetch(name, Blog::Constants::EMPTY_ARRAY).each_with_object(attrs.dup) do |key, linked|
          record = linked.delete(key)
          linked[:"#{key}_id"] = record.id if record
        end
      end
    end

    module Tagging
      REPOS = {
        decision: [:decisions, "repos.decision_mutations", "repos.decision_queries"],
        journal_entry: [:record, "repos.journal_entry_mutations", "repos.journal_entry_queries"],
        post: [:posts, "repos.post_repo"],
        project: [:projects, "repos.project_mutations", "repos.project_queries"],
        task: [:tasks, "repos.task_repo"],
      }.freeze

      def self.call(name, record, names)
        return record unless REPOS.key?(name)

        repo(name, REPOS.fetch(name)[1]).replace_tags(record.id, names) if names

        repo_for(name).by_id(record.id)
      end

      def self.repo(name, key) = Hanami.app.slices[REPOS.fetch(name).first][key]

      def self.repo_for(name) = repo(name, REPOS.fetch(name).last)
    end

    class FactoryHelper < Module
      attr_reader :slice_name

      def initialize(slice_name = nil)
        super()
        @slice_name = slice_name

        define_method(:factory) { |name| Factories.for_factory(name, slice_name) }
        define_method(:build) { |name, *traits, **attrs| factory(name).build(name, *traits, **attrs.except(:tags)) }
        define_method(:create) { |name, *traits, **attrs| factory(name).create(name, *traits, **attrs) }
      end
    end
  end
end

RSpec.configure do |config|
  config.include Spec::DB::FactoryHelper.new
end
