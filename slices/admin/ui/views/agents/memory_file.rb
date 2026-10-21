# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Agents
        class MemoryFile < View
          include Components::Agents

          LIVE_TABLES = %w[agent_sessions memory_events memory_facts memory_files projects record_links tasks].freeze

          prop :file, Blog::Types::Instance(ROM::Struct)
          prop :history, Blog::Types::Instance(Blog::Structs::Paged)
          prop :history_count, Blog::Types::Integer
          prop :history_marks, Blog::Types::Hash
          prop :scopes, Blog::Types::Array
          prop :form, Blog::Types::Hash
          prop :records, Blog::Types::Hash

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            head
            div(class: "g-main") do
              div(class: "stack") do
                MemoryIndexLine(file: @file, scope: current, form: @form)
                MemoryFacts(file: @file, form: @form)
              end
              aside(class: "stack") { side }
            end
          end

          private

          def current = @scopes.find { it.key == Helpers::MemoryScope.key(@file) }

          def delete_form
            DeleteForm(
              action: path(:admin_delete_memory_file, id: @file.id), label: t(".delete"),
              confirm: t(".confirm_delete", path: @file.path),
            )
          end

          def head
            PageHead(title: @file.path, sub: lede) { BackLink(href: path(:admin_memory_files)) { t(".back") } }
          end

          def lede
            facts = t(".fact_count", count: @file.facts.size)

            listed = t(Helpers::MemoryScope.listed_for(@file.scope, named: true), name: current.name.to_s)

            [@file.description, "#{facts}. #{listed}."].compact.join(" · ")
          end

          def linked
            find_path = path(:admin_memory_file, id: @file.id)

            RecordLinks::Section(records: @records, kind: "memory_file", id: @file.id, find_path:)
          end

          def scope_form
            errors = @form[:name] == :scope ? @form[:errors] : Blog::Constants::EMPTY_HASH
            selected = @form.dig(:values, :scope) || current.key

            Form(action: path(:admin_change_memory_file_scope, id: @file.id), class: "stack-form") do
              Field(label: t(".scope"), name: :scope, errors:, error: MemoryFieldError) do |control|
                MemoryScopeSelect(**control, scopes: @scopes, selected:)
              end
              Button(type: "submit", small: true) { t(".move") }
            end
          end

          def side
            Card { scope_form }
            linked
            MemoryHistory(file: @file, events: @history, count: @history_count, **@history_marks)
            div { delete_form }
          end
        end
      end
    end
  end
end
