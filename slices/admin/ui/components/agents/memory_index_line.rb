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
          prop :described_at, Blog::Types::Time

          def view_template
            Card(title: t(".title"), note: t(".note")) do
              line
              div(class: "memory-index-description") do
                MemoryDescription(file: @file, class: "memory-index-text")
                edit_form
              end
              byline
            end
          end

          private

          def byline
            who = (Helpers::AgentBrand.model(@file.description_model) if @file.description_agent) || t(".you")

            Hint { dotted(t(".by", who:), l(Blog::TimeZone.local(@described_at), format: :medium)) }
          end

          def description_field
            errors = mine? ? @form[:errors] : Blog::Constants::EMPTY_HASH
            value = mine? ? @form.dig(:values, :description) : @file.description

            Field(label: t(".description"), name: :description, errors:, error: MemoryFieldError) do |control|
              Input(**control, name: "memory_file[description]", value:, placeholder: t(".placeholder"))
            end
          end

          def edit_form
            details(class: "memory-edit", open: mine?) do
              Button(summary: true, small: true, variant: :gh, icon: :edit) { t(".edit") }
              Form(action: path(:admin_describe_memory_file, id: @file.id), class: "memory-index-form") do
                description_field
                Button(type: "submit", variant: :pri, small: true) { t(".save") }
                Button(href: path(:admin_memory_file, id: @file.id), variant: :gh, small: true) { t(".cancel") }
              end
            end
          end

          def line
            p(class: "memory-index-head") do
              span(class: "memory-index-path") { @file.path }
              Pill(icon: Helpers::MemoryScope.icon(@scope.kind)) { t(Helpers::MemoryScope.kind(@scope.kind)) }
              span(class: "meta") { t(".facts", count: @file.facts.size) }
            end
          end

          def mine? = @form[:name] == FORM
        end
      end
    end
  end
end
