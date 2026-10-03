# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Decisions
        class Show < View
          include Components::Decisions

          def initialize(decision:, form:)
            super()
            @decision = decision
            @form = form
          end

          def view_template
            article(class: "task-read", data: { decision_read: @decision.id }) do
              head
              p(class: "task-meta task-read-meta") { Status(status: @decision.status) }
              Card(label: t(".problem_label"), title: t(".problem")) do
                div(class: "task-body post-body") { raw(safe(::Tasks::Markdown.to_html(@decision.problem).strip)) }
              end
              Options(decision: @decision, form: @form)
              Closing(decision: @decision, form: @form)
            end
          end

          private

          def head
            PageHead(title: @decision.title, kicker: t(".kicker")) do
              a(class: "btn", href: path(:admin_decisions, status: @decision.status)) do
                i(class: "fa-solid fa-arrow-left", aria: { hidden: "true" })
                span { t(".back") }
              end
              a(class: "btn", href: path(:admin_edit_decision, id: @decision.id)) do
                i(class: "fa-regular fa-pen-to-square", aria: { hidden: "true" })
                span { t(".edit") }
              end
            end
          end
        end
      end
    end
  end
end
