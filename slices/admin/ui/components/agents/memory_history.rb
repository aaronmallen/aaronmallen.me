# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class MemoryHistory < Component
          EDIT = Blog::Types::MemoryEventOp["edit"]
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
            div(class: "memory-event-acts") do
              session(event.session_id) if event.session_id
              revert(event)
            end
          end

          def author(event)
            return t(".you") unless event.agent

            t(".agent", agent: event.agent, model: Helpers::AgentBrand.model(event.model))
          end

          def entry(event)
            li(class: "memory-event", id: "memory-event-#{event.id}") do
              Moment(at: event.created_at, class: "timeline-time")
              p(class: "memory-event-what") do
                strong { author(event) }
                plain " #{what(event)}"
              end
              quote(event.was_text) if event.op == EDIT
              quote(event.text || event.was_text)
              acts(event)
            end
          end

          def quote(text) = (p(class: "memory-quote") { text } if text)

          def revert(event)
            return span(class: "meta") { t(".reverted") } if @reverted.include?(event.id)
            return unless REVERTIBLE.include?(event.op) && @latest[event.memory_fact_id] == event.id

            ButtonForm(
              action: path(:admin_revert_memory_file_event, id: @file.id, event_id: event.id), label: t(".revert"),
              variant: :gh, confirm: t(".confirm_revert"),
            )
          end

          def session(id)
            Button(href: path(:admin_agent_sessions, session: id), small: true, variant: :gh) { t(".session") }
          end

          def what(event)
            return t(OPS.fetch(event.op)) unless event.reverted_event_id

            t(REVERTS.fetch(@undone.fetch(event.reverted_event_id)))
          end
        end
      end
    end
  end
end
