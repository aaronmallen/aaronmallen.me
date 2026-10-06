# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class Timeline < Component
          ROUTES = {
            create: :admin_create_decision_comment, update: :admin_update_decision_comment,
            delete: :admin_delete_decision_comment,
          }.freeze

          prop :decision, Blog::Types::Instance(ROM::Struct)
          prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :form, Blog::Types::Hash

          def view_template
            Card(label: t(".label"), title: t(".title"), class: "timeline-card") do
              Hint { t(".empty") } if @entries.empty?
              thread
            end
          end

          private

          def commenting
            return Blog::Constants::EMPTY_HASH unless @form[:name] == :comment

            { id: @form[:id], body: Blog::Types::Text[@form[:params][:body]], errors: @form[:errors] }
          end

          def options = @options ||= @decision.options.to_h { [it.id, it.title] }

          def thread
            CommentThread(
              record_id: @decision.id, entries: @entries, routes: ROUTES, scope: "decision", form: commenting,
              error: FieldError,
            ) do |thread|
              thread.event { |entry| TimelineEvent(entry:, options:) }
            end
          end
        end
      end
    end
  end
end
