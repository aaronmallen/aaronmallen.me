# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Agents
        class Memories < View
          include Components::Agents

          LIVE_TABLES = %w[memory_events memory_facts memory_files projects tasks].freeze
          ICONS = {
            "global" => "fa-solid fa-globe", "repo" => "fa-brands fa-github", "project" => "fa-solid fa-cube",
            "task" => "fa-solid fa-list-check",
          }.freeze
          FILTERS = ["all", *Blog::Types::MemoryScope.values].to_h { [it, ".filters.#{it}"] }.freeze
          SEARCH_ID = "memories-search"

          prop :files, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :scope, Blog::Types::MemoryScope.optional
          prop :query, Blog::Types::String.optional
          prop :repo, Blog::Types::String.optional
          prop :repos, Blog::Types::Array.of(Blog::Types::String)
          prop :index, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :latest, Blog::Types::Hash
          prop :changes, Blog::Types::Integer
          prop :counts, Blog::Types::Hash
          prop :scopes, Blog::Types::Array
          prop :values, Blog::Types::Hash
          prop :errors, Blog::Types::Hash

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            PageHead(title: t(".heading"), sub: lede)
            MemoryNewForm(scopes: @scopes, values: @values, errors: @errors, keep:)
            div(class: "g-main") do
              div(class: "stack") { list }
              aside(class: "stack") do
                MemoryIndex(repo: @repo, repos: @repos, files: @index, keep:)
              end
            end
          end

          private

          def filter_link(filter)
            scope = filter unless filter == FILTERS.keys.first
            count = scope ? @counts.fetch(scope) : @counts.values.sum

            a(
              class: "search-kind", href: path(:admin_memory_files, **{ scope:, query: @query }.compact),
              aria: { current: ("page" if scope == @scope) },
            ) { t(FILTERS.fetch(filter), count:) }
          end

          def filters
            div(class: "memory-filters") do
              nav(class: "search-kinds", aria: { label: t(".scope") }) { FILTERS.each_key { filter_link(it) } }
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

            Card(note: t(Helpers::MemoryScope.listed_for(choice.kind))) do |card|
              card.heading do
                Icon([ICONS.fetch(choice.kind), "memory-scope-icon"])
                plain scope_text(choice)
              end
              files.each { MemoryRow(file: it, event: @latest[it.id], query: @query) }
            end
          end

          def groups
            return Empty { @query ? t(".no_match", query: @query) : t(".empty") } if @files.empty?

            @files.group_by { Helpers::MemoryScope.key(it) }.each { |key, files| group(key, files) }
          end

          def keep = { scope: @scope, query: @query }.compact

          def lede
            facts = t(".facts", count: @files.sum { it.facts.size })

            "#{t('.lede', facts:, count: @files.size)} #{t('.changes', count: @changes)}"
          end

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
