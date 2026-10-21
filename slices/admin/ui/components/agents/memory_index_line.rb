# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class MemoryIndexLine < Component
          FORM = :describe

          prop :file, Blog::Types::Instance(ROM::Struct)
          prop :scope, Blog::Types::Instance(Data)
          prop :form, Blog::Types::Hash

          def view_template
            Card(title: t(".title"), note: t(".note")) do
              line
              p(class: "memory-index-description") { @file.description }
              edit_form
            end
          end

          private

          def description_field
            errors = mine? ? @form[:errors] : Blog::Constants::EMPTY_HASH
            value = mine? ? @form.dig(:values, :description) : @file.description

            Field(label: t(".description"), name: :description, errors:, error: MemoryFieldError) do |control|
              Input(**control, name: "memory_file[description]", value:)
            end
          end

          def edit_form
            details(class: "memory-edit", open: mine?) do
              Button(summary: true, small: true, variant: :gh, icon: :edit) { t(".edit") }
              Form(action: path(:admin_describe_memory_file, id: @file.id), class: "stack-form") do
                description_field
                Button(type: "submit", variant: :pri, small: true) { t(".save") }
              end
            end
          end

          def line
            p(class: "memory-index-line") do
              code { @file.path }
              whitespace
              Pill { t(Helpers::MemoryScope.label(@scope.kind), name: @scope.name.to_s) }
              whitespace
              span(class: "meta") { t(".facts", count: @file.facts.size) }
            end
          end

          def mine? = @form[:name] == FORM
        end
      end
    end
  end
end
