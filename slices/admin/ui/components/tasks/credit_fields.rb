# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class CreditFields < Component
          NAME = "task[contributors]"
          NEW = "#{NAME}[agents][new]".freeze
          OWNER = Blog::Types::ContributorKind["owner"]

          prop :scope, Blog::Types::String
          prop :credits, Blog::Types::Array.of(Blog::Types::Hash)
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def view_template
            Field(label: t(".label")) do
              div(class: "task-credits", **FieldError.control_attributes(:contributors, @errors, @scope)) do
                Checkbox(label: t(".owner"), name: "#{NAME}[owner]", checked: owner?)
                agents.each_with_index { |credit, index| agent(credit, index) }
              end
              typed_agent
              FieldError(field: :contributors, errors: @errors, scope: @scope)
            end
          end

          private

          def agent(credit, index)
            name = "#{NAME}[agents][#{index}]"

            input(type: "hidden", name: "#{name}[agent]", value: credit[:agent])
            input(type: "hidden", name: "#{name}[model]", value: credit[:model])
            Checkbox(label: t(".agent", **credit.slice(:agent, :model)), name: "#{name}[keep]", checked: true)
          end

          def agents = sorted.fetch(true, Blog::Constants::EMPTY_ARRAY)

          def owner? = @credits.any? { it[:kind] == OWNER }

          def sorted
            @sorted ||= @credits.reject { it[:kind] == OWNER }.group_by { Blog::Types::Contributor.valid?(it) }
          end

          def typed = sorted.fetch(false, Blog::Constants::EMPTY_ARRAY).first || Blog::Constants::EMPTY_HASH

          def typed_agent
            div(class: "task-form-pair") do
              typed_input(:agent, t(".agent_placeholder"), t(".new_agent"))
              typed_input(:model, t(".model_placeholder"), t(".new_model"))
            end
          end

          def typed_input(key, placeholder, label)
            Input(name: "#{NEW}[#{key}]", value: typed[key], autocomplete: "off", placeholder:, aria: { label: })
          end
        end
      end
    end
  end
end
