# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Agents
        class MemoryFile < View
          include Components::Agents

          LIVE_TABLES = %w[agent_sessions memory_events memory_facts memory_files projects record_links tasks].freeze
          LOADS_FOR = Blog::Types::MemoryScope.values.to_h { [it, ".loads_for.#{it}"] }.freeze

          prop :file, Blog::Types::Instance(ROM::Struct)
          prop :history, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :loaded, Blog::Types::Bool, default: false
          prop :scopes, Blog::Types::Array
          prop :form, Blog::Types::Hash
          prop :records, Blog::Types::Hash

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            head
            div(class: "g-main") do
              div(class: "stack") { @loaded ? markdown : MemoryFacts(file: @file, form: @form) }
              aside(class: "stack") { side }
            end
          end

          private

          def current = @scopes.find { it.key == Helpers::MemoryScope.key(@file) }

          def delete_form
            DeleteForm(
              action: path(:admin_delete_agent_memory_file, id: @file.id), label: t(".delete"),
              confirm: t(".confirm_delete", path: @file.path),
            )
          end

          def head
            PageHead(title: @file.path, sub: lede) do
              BackLink(href: path(:admin_agent_memories)) { t(".back") }
              SegmentedLinks(label: t(".show"), items: [mode(".facts", false), mode(".loaded", true)])
            end
          end

          def lede
            facts = t(".fact_count", count: @file.facts.size)

            "#{facts}. #{t(LOADS_FOR.fetch(@file.scope), name: current.name.to_s)}."
          end

          def linked
            find_path = path(:admin_agent_memory_file, id: @file.id)

            RecordLinks::Section(records: @records, kind: "memory_file", id: @file.id, find_path:)
          end

          def markdown
            Card(title: t(".as_loaded"), note: t(".markdown")) { pre(class: "memory-raw") { @file.markdown } }
          end

          def mode(text, loaded)
            query = loaded ? { view: Operations::BuildMemoryFilePage::LOADED } : Blog::Constants::EMPTY_HASH

            { text: t(text), current: @loaded == loaded, href: path(:admin_agent_memory_file, id: @file.id, **query) }
          end

          def scope_form
            errors = @form[:name] == :scope ? @form[:errors] : Blog::Constants::EMPTY_HASH
            selected = @form.dig(:values, :scope) || current.key

            Form(action: path(:admin_change_agent_memory_scope, id: @file.id), class: "stack-form") do
              Field(label: t(".scope"), name: :scope, errors:, error: MemoryFieldError) do |control|
                MemoryScopeSelect(**control, scopes: @scopes, selected:)
              end
              Button(type: "submit", small: true) { t(".move") }
            end
          end

          def side
            Card { scope_form }
            linked
            MemoryHistory(file: @file, events: @history)
            div { delete_form }
          end
        end
      end
    end
  end
end
