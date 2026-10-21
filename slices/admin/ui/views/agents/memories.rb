# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Agents
        class Memories < View
          include Components::Agents

          LIVE_TABLES = %w[memory_events memory_facts memory_files projects tasks].freeze
          FILTERS = ["all", *Blog::Types::MemoryScope.values].to_h { [it, ".filters.#{it}"] }.freeze
          SEARCH_ID = "memories-search"

          prop :files, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :scope, Blog::Types::MemoryScope.optional
          prop :query, Blog::Types::String.optional
          prop :repo, Blog::Types::String.optional
          prop :repos, Blog::Types::Array.of(Blog::Types::String)
          prop :index, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :counts, Blog::Types::Hash
          prop :scopes, Blog::Types::Array
          prop :values, Blog::Types::Hash
          prop :errors, Blog::Types::Hash

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            PageHead(title: t(".heading"), sub: lede)
            MemoryNewForm(scopes: @scopes, values: @values, errors: @errors)
            div(class: "g-main") do
              div(class: "stack") { list }
              aside(class: "stack") do
                MemoryIndex(repo: @repo, repos: @repos, files: @index, keep: { scope: @scope, query: @query }.compact)
              end
            end
          end

          private

          def filter_link(filter)
            scope = filter unless filter == FILTERS.keys.first
            count = scope ? @counts.fetch(scope) : @counts.values.sum

            {
              text: t(FILTERS.fetch(filter), count:), current: scope == @scope,
              href: path(:admin_memory_files, **{ scope:, query: @query }.compact),
            }
          end

          def filters
            div(class: "memory-filters") do
              SegmentedLinks(label: t(".scope"), items: FILTERS.keys.map { filter_link(it) })
              AutoForm(action: path(:admin_memory_files), role: "search") do
                input(type: "hidden", name: "scope", value: @scope) if @scope
                SearchField(
                  id: SEARCH_ID, label: t(".search"), name: "query", value: @query, placeholder: t(".placeholder"),
                )
              end
            end
          end

          def group(key, files)
            choice = scoped(key)

            Card(title: scope_text(choice), note: t(Helpers::MemoryScope.listed_for(choice.kind))) do
              files.each { MemoryRow(file: it, query: @query) }
            end
          end

          def groups
            return Empty { @query ? t(".no_match", query: @query) : t(".empty") } if @files.empty?

            @files.group_by { Helpers::MemoryScope.key(it) }.each { |key, files| group(key, files) }
          end

          def lede = t(".lede", facts: t(".facts", count: @files.sum { it.facts.size }), count: @files.size)

          def list
            filters
            groups
          end

          def scope_text(choice) = t(Helpers::MemoryScope.label(choice.kind), name: choice.name.to_s)

          def scoped(key) = @scopes.find { it.key == key }
        end
      end
    end
  end
end
