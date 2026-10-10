# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class TimelineEvent < Component
          EVENTS = {
            Blog::Types::DecisionEventKind["opened"] => ["fa-regular fa-circle", ".opened"],
            Blog::Types::DecisionEventKind["option_added"] => ["fa-solid fa-plus", ".option_added"],
            Blog::Types::DecisionEventKind["option_edited"] => ["fa-regular fa-pen-to-square", ".option_edited"],
            Blog::Types::DecisionEventKind["edited"] => ["fa-regular fa-pen-to-square", ".edited"],
            Blog::Types::DecisionEventKind["resolved"] => ["fa-solid fa-circle-check", ".resolved"],
            Blog::Types::DecisionEventKind["dropped"] => ["fa-solid fa-ban", ".dropped"],
            Blog::Types::DecisionEventKind["reopened"] => ["fa-solid fa-rotate-left", ".reopened"],
          }.freeze

          prop :entry, Blog::Types::Instance(ROM::Struct)
          prop :options, Blog::Types::Hash

          def view_template
            li(class: "decision-event", **attributes) do
              Moment(at: @entry.occurred_at, format: :short, class: "decision-event-time")
              div(class: "decision-event-text") do
                line
                MarkdownBody(source: body, markdown: ::Tasks::Markdown, class: "markdown-body") if body
              end
            end
          end

          private

          def attributes = { id: "decision-event-#{@entry.source_id}", data: { decision_event: @entry.kind } }

          def body = @entry.reason || @entry.note

          def line
            icon, key = EVENTS.fetch(@entry.kind)

            p(class: "decision-event-line") do
              Icon(icon)
              plain t(key, option: @options[@entry.option_id])
            end
          end
        end
      end
    end
  end
end
