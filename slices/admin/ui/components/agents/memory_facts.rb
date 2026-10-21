# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class MemoryFacts < Component
          FACT_TYPES = Blog::Types::MemoryFactType.values.freeze
          COLORS = { "preference" => :violet, "convention" => :blue, "gotcha" => :orange, "context" => :green }.freeze
          CONTEXT = Blog::Types::MemoryFactType["context"]
          TYPES = FACT_TYPES.to_h { [it, ".types.#{it}"] }.freeze
          ROWS = { add: "1", edit: "2" }.freeze

          prop :file, Blog::Types::Instance(ROM::Struct)
          prop :form, Blog::Types::Hash

          def view_template
            Card(title: t(".title"), count: @file.facts.size) do
              Empty { t(".empty") } if @file.facts.empty?
              ul(class: "memory-fact-list") { sorted.each { fact(it) } } if @file.facts.any?
              add_form
            end
          end

          private

          def add_form
            Form(action: path(:admin_add_memory_file_fact, id: @file.id), class: "memory-fact-form") do
              fields(errors(:add), "memory-new-fact", values(:add, type: CONTEXT, text: ""), t(".new"), :add)
              Button(type: "submit", icon: "fa-solid fa-plus") { t(".add") }
            end
          end

          def body(fact)
            div(class: "memory-fact-body") do
              p(class: "memory-fact-text") do
                AgentMark(model: fact.model) if fact.agent?
                plain fact.text
              end
              Hint { dotted(Helpers::AgentBrand.author(fact) || t(".you"), when_at(fact)) }
            end
          end

          def edit_acts
            div(class: "memory-fact-edit-acts") do
              Button(type: "submit", variant: :pri, small: true) { t(".save") }
              Button(href: path(:admin_memory_file, id: @file.id), variant: :gh, small: true) { t(".cancel") }
            end
          end

          def edit_form(fact)
            id_prefix = "memory-fact-#{fact.id}"
            saved = values(:edit, fact.id, type: fact.type, text: fact.text)

            details(class: "memory-edit", open: mine?(:edit, fact.id)) do
              Button(summary: true, small: true, variant: :gh, icon: :edit, label: t(".edit"))
              Form(action: edit_path(fact), class: "memory-fact-edit") do
                fields(errors(:edit, fact.id), id_prefix, saved, t(".fact"), :edit)
                edit_acts
              end
            end
          end

          def edit_path(fact) = path(:admin_edit_memory_file_fact, id: @file.id, fact_id: fact.id)

          def errors(name, id = nil) = mine?(name, id) ? @form[:errors] : Blog::Constants::EMPTY_HASH

          def fact(fact)
            li(class: "memory-fact", id: "memory-fact-#{fact.id}", data: { key_row: true }) do
              div(class: "memory-fact-main") do
                Pill(color: COLORS.fetch(fact.type)) { t(TYPES.fetch(fact.type)) }
                body(fact)
              end
              div(class: "memory-fact-acts hov") do
                edit_form(fact)
                remove_form(fact)
              end
            end
          end

          def fields(field_errors, id_prefix, shown, label, form)
            field = { errors: field_errors, error: MemoryFieldError, scope: id_prefix }

            Field(label: t(".type"), name: :type, **field) do |control|
              Select(**control, name: "fact[type]", options: types, selected: shown[:type])
            end
            Field(label:, name: :text, **field) do |control|
              placeholder = t(".placeholder") if form == :add
              Textarea(**control, name: "fact[text]", value: shown[:text], rows: ROWS.fetch(form), placeholder:)
            end
          end

          def mine?(name, id = nil) = @form[:name] == name && @form[:id] == id

          def remove_form(fact)
            ButtonForm(
              action: path(:admin_remove_memory_file_fact, id: @file.id, fact_id: fact.id), label: t(".remove"),
              variant: :gh, icon: :trash, icon_only: true, confirm: t(".confirm_remove"),
            )
          end

          def sorted = @file.facts.sort_by { [FACT_TYPES.index(it.type), it.id] }

          def types = TYPES.transform_values { t(it) }

          def values(name, id = nil, **saved)
            mine?(name, id) ? { **saved, **@form[:values].compact } : saved
          end

          def when_at(fact) = l(Blog::TimeZone.local(fact.updated_at), format: :medium)
        end
      end
    end
  end
end
