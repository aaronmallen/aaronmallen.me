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
            return li(class: "task-event", **attributes) { line } unless body

            li(class: "task-comment", **attributes) do
              div(class: "task-comment-head") { line }
              div(class: "task-body post-body task-comment-body") { raw(safe(::Tasks::Markdown.to_html(body).strip)) }
            end
          end

          private

          def attributes = { id: "decision-event-#{@entry.source_id}", data: { decision_event: @entry.kind } }

          def body = @entry.reason || @entry.note

          def line
            icon, key = EVENTS.fetch(@entry.kind)

            i(class: ["task-event-icon", icon], aria: { hidden: "true" })
            span(class: "task-event-text") { t(key, option: @options[@entry.option_id]) }
            time(class: "task-comment-time", datetime: @entry.occurred_at.iso8601) { stamp(@entry.occurred_at) }
          end

          def stamp(time) = l(Blog::TimeZone.local(time), format: :medium)
        end
      end
    end
  end
end
