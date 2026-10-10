# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class Closing < Component
          prop :decision, Blog::Types::Instance(ROM::Struct)
          prop :form, Blog::Types::Hash

          def view_template
            Card(title: t(".label")) do
              if @decision.open?
                part(".resolve_title") { resolve }
                part(".drop_title") { reason_form(:drop, :warn) }
              else
                reason_form(:reopen, :pri)
              end
            end
          end

          private

          def choice_field
            errors = @form[:name] == :resolve ? @form[:errors] : Blog::Constants::EMPTY_HASH

            Field(label: t(".option"), name: :option_id, errors:, error: FieldError,
                  scope: "decision-resolve") do |control|
              Select(**control, name: "decision[option_id]", options: choices, selected:, required: true)
            end
          end

          def choices
            { Blog::Constants::EMPTY_STRING => t(".pick") }.merge(@decision.options.to_h { [it.id.to_s, it.title] })
          end

          def part(title_key)
            div(class: "decision-close-part") do
              h3(class: "decision-close-title") { t(title_key) }
              yield
            end
          end

          def reason_form(name, variant, &)
            route = :"admin_#{name}_decision"
            ReasonForm(decision: @decision, form: @form, name:, route:, variant:, &)
          end

          def resolve
            return Hint { t(".no_options") } if @decision.options.empty?

            reason_form(:resolve, :pri) { choice_field }
          end

          def selected
            return Blog::Constants::EMPTY_STRING unless @form[:name] == :resolve

            Blog::Types::Text[@form[:params][:option_id]]
          end
        end
      end
    end
  end
end
