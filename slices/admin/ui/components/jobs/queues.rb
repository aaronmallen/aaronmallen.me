# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Jobs
        class Queues < Component
          prop :queues, Blog::Types::Array.of(Blog::Types::Instance(Data))

          def view_template
            empty = t(".none") if @queues.empty?

            Card(as: :aside, title: t(".title"), note: Blog::Helpers::Figures.count(@queues.size), empty:) do
              @queues.each { queue(it) }
              Hint { t(".hint") }
            end
          end

          private

          def queue(found)
            waiting = found.size.positive?
            href = path(:admin_settings_jobs, queue: found.name) if waiting
            sub = waiting ? t(".waited", for: Blog::Helpers::Figures.elapsed(found.latency)) : t(".empty")

            ListItem(title: found.name, href:, sub:) do
              span(class: ["jobs-queue-size", tone(found.latency)]) { Blog::Helpers::Figures.count(found.size) }
            end
          end

          def tone(latency)
            if latency >= Health::STUCK then Health::BAD
            elsif latency >= Health::LATE then Health::WARN
            end
          end
        end
      end
    end
  end
end
