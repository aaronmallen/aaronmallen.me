# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class MemoryHistory < Component
          CHANGES = %w[edit describe].map { Blog::Types::MemoryEventOp[it] }.freeze
          REMOVE = Blog::Types::MemoryEventOp["remove"]
          OPS = Blog::Types::MemoryEventOp.values.to_h { [it, ".ops.#{it}"] }.freeze
          REVERTIBLE = ::Agents::Operations::RevertMemoryEvent::REVERTIBLE
          REVERTS = REVERTIBLE.to_h { [it, ".reverts.#{it}"] }.freeze

          prop :file, Blog::Types::Instance(ROM::Struct)
          prop :events, Blog::Types::Instance(Blog::Structs::Paged)
          prop :count, Blog::Types::Integer
          prop :latest, Blog::Types::Hash
          prop :reverted, Blog::Types::Instance(Set)
          prop :undone, Blog::Types::Hash
          prop :params, Blog::Types::Hash, default: -> { {} }

          def view_template
            Card(title: t(".title"), count: @count) do
              ol(class: "timeline") { @events.rows.each { entry(it) } }
              Pager(page: @events, route: :admin_memory_file, params: { id: @file.id, **@params })
            end
          end

          private

          def acts(event)
            span(class: "memory-event-acts") do
              session(event.session_id) if event.session_id
              revert(event)
            end
          end

          def entry(event)
            li(class: "timeline-event memory-event", id: "memory-event-#{event.id}") do
              Moment(at: event.created_at, class: "timeline-time")
              span(class: "memory-event-what") do
                strong { Helpers::AgentBrand.author(event) || t(".you") }
                plain " #{what(event)}"
                quotes(event)
                acts(event)
              end
            end
          end

          def quotes(event)
            return if event.reverted_event_id
            return plain(" #{t('.change', was: event.was_text, now: event.text)}") if CHANGES.include?(event.op)

            text = event.op == REMOVE ? event.was_text : event.text
            plain " #{t('.quote', text:)}" if text
          end

          def revert(event)
            return span(class: "meta") { t(".reverted") } if @reverted.include?(event.id)
            return unless REVERTIBLE.include?(event.op) && @latest[event.memory_fact_id] == event.id

            Form(
              action: path(:admin_revert_memory_file_event, id: @file.id, event_id: event.id),
              data: { confirm: t(".confirm_revert") },
            ) { button(type: "submit", class: "memory-link") { t(".revert") } }
          end

          def session(id) = a(class: "memory-link", href: path(:admin_agent_sessions, session: id)) { t(".session") }

          def what(event)
            return t(OPS.fetch(event.op)) unless event.reverted_event_id

            t(REVERTS.fetch(@undone.fetch(event.reverted_event_id)))
          end
        end
      end
    end
  end
end
