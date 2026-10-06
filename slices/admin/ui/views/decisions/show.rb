# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Decisions
        class Show < View
          include Components::Decisions

          def initialize(decision:, form:, timeline:, records:)
            super()
            @decision = decision
            @form = form
            @timeline = timeline
            @records = records
          end

          def view_template
            article(class: "read-page", data: { decision_read: @decision.id }) do
              head
              meta
              problem
              Options(decision: @decision, form: @form)
              Closing(decision: @decision, form: @form)
              Timeline(decision: @decision, entries: @timeline, form: @form)
              linked
            end
          end

          private

          def head
            PageHead(title: @decision.title, kicker: t(".kicker")) do
              BackLink(href: path(:admin_decisions, status: @decision.status)) { t(".back") }
              Button(href: path(:admin_edit_decision, id: @decision.id), icon: "fa-regular fa-pen-to-square") do
                t(".edit")
              end
            end
          end

          def linked
            id = @decision.id

            RecordLinks::Section(
              records: @records, scope: "decision-#{id}-record", id:, unlink_route: :admin_unlink_decision_record,
              link_path: path(:admin_link_decision_record, id:), find_path: path(:admin_decision, id:),
            )
          end

          def meta
            p(class: "read-meta") do
              Status(status: @decision.status)
              @decision.tags.each { Tag(tag: it) }
            end
          end

          def problem
            Card(label: t(".problem_label"), title: t(".problem")) do
              div(class: "markdown-body post-body") { raw(safe(::Tasks::Markdown.to_html(@decision.problem).strip)) }
            end
          end
        end
      end
    end
  end
end
