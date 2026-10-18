# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class MemoryFacts < Component
          FACT_TYPES = Blog::Types::MemoryFactType.values.freeze
          COLORS = { "preference" => :violet, "convention" => :blue, "gotcha" => :orange, "context" => :green }.freeze
          CONTEXT = Blog::Types::MemoryFactType["context"]
          HEADINGS = FACT_TYPES.to_h { [it, ".headings.#{it}"] }.freeze
          TYPES = FACT_TYPES.to_h { [it, ".types.#{it}"] }.freeze
          ROWS = "3"

          prop :file, Blog::Types::Instance(ROM::Struct)
          prop :form, Blog::Types::Hash

          def view_template
            Card(title: t(".title"), count: @file.facts.size) do
              Empty { t(".empty") } if @file.facts.empty?
              FACT_TYPES.each { typed(it) }
              add_form
            end
          end

          private

          def add_form
            Form(action: path(:admin_add_agent_memory_fact, id: @file.id), class: "memory-fact-form") do
              fields(errors(:add), "memory-new-fact", values(:add, type: CONTEXT, text: ""), t(".new"))
              Button(type: "submit", icon: "fa-solid fa-plus") { t(".add") }
            end
          end

          def author(fact)
            return t(".you") unless fact.agent?

            t(".agent", agent: fact.agent, model: Helpers::AgentBrand.model(fact.model))
          end

          def body(fact)
            div(class: "memory-fact-body") do
              p(class: "memory-fact-text") { fact.text }
              Hint { dotted(author(fact), l(Blog::TimeZone.local(fact.updated_at), format: :medium)) }
            end
          end

          def edit_form(fact)
            id_prefix = "memory-fact-#{fact.id}"
            saved = values(:edit, fact.id, type: fact.type, text: fact.text)

            details(class: "memory-edit", open: mine?(:edit, fact.id)) do
              Button(summary: true, small: true, variant: :gh, icon: :edit) { t(".edit") }
              Form(action: path(:admin_edit_agent_memory_fact, id: @file.id, fact_id: fact.id), class: "stack-form") do
                fields(errors(:edit, fact.id), id_prefix, saved, t(".fact"))
                Button(type: "submit", variant: :pri, small: true) { t(".save") }
              end
            end
          end

          def errors(name, id = nil) = mine?(name, id) ? @form[:errors] : Blog::Constants::EMPTY_HASH

          def fact(fact)
            li(class: "memory-fact", id: "memory-fact-#{fact.id}") do
              Pill(color: COLORS.fetch(fact.type)) { t(TYPES.fetch(fact.type)) }
              body(fact)
              div(class: "memory-fact-acts") do
                edit_form(fact)
                remove_form(fact)
              end
            end
          end

          def fields(field_errors, id_prefix, shown, label)
            field = { errors: field_errors, error: MemoryFieldError, scope: id_prefix }

            Field(label: t(".type"), name: :type, **field) do |control|
              Select(**control, name: "fact[type]", options: types, selected: shown[:type])
            end
            Field(label:, name: :text, **field) do |control|
              Textarea(**control, name: "fact[text]", value: shown[:text], rows: ROWS)
            end
          end

          def mine?(name, id = nil) = @form[:name] == name && @form[:id] == id

          def remove_form(fact)
            ButtonForm(
              action: path(:admin_remove_agent_memory_fact, id: @file.id, fact_id: fact.id), label: t(".remove"),
              variant: :gh, icon: :trash, icon_only: true, confirm: t(".confirm_remove"),
            )
          end

          def typed(type)
            facts = @file.facts.select { it.type == type }
            return if facts.empty?

            h3(class: "memory-type") { t(HEADINGS.fetch(type)) }
            ul(class: "memory-fact-list") { facts.each { fact(it) } }
          end

          def types = TYPES.transform_values { t(it) }

          def values(name, id = nil, **saved)
            mine?(name, id) ? { **saved, **@form[:values].compact } : saved
          end
        end
      end
    end
  end
end
