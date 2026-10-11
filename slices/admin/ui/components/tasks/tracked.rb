# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class Tracked < Component
          MILLISECONDS = 1000
          SPAN = "\0"

          prop :task, Blog::Types::Instance(ROM::Struct)
          prop :text, Blog::Types::String

          def view_template
            before, after = @text.split(SPAN, 2)
            plain before
            figure
            plain after.to_s
          end

          private

          def figure
            hours = Blog::Helpers::Figures.hours(@task.tracked_seconds)
            session = @task.running_session
            return plain(hours) unless session

            span(data: { tracked_since: ((session.started_at.to_r - @task.worked_seconds) * MILLISECONDS).floor }) do
              hours
            end
          end
        end
      end
    end
  end
end
