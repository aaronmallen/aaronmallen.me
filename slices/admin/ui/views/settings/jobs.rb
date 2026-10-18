# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Settings
        class Jobs < View
          prop :cron, Blog::Types::Array.of(Blog::Types::Instance(Data))
          prop :cron_filter, Blog::Types::CronFilter
          prop :health, Blog::Types::Instance(Data)
          prop :running, Blog::Types::Array.of(Blog::Types::Instance(Data)), default: -> { [] }
          prop :queues, Blog::Types::Array.of(Blog::Types::Instance(Data)), default: -> { [] }
          prop :queue, Blog::Types::Instance(Data).optional, default: nil

          def view_template
            SettingsHead(tab: :jobs, title: t(".heading"))
            div(class: "jobs") do
              Components::Jobs::Warnings(health: @health)
              Components::Jobs::Health(health: @health)
              work unless @health.down?
              Components::Jobs::Cron(entries: @cron, filter: @cron_filter)
            end
          end

          private

          def work
            div(class: "g-main") do
              Components::Jobs::Running(processes: @running)
              Components::Jobs::Queues(queues: @queues)
            end
            Components::Jobs::QueueDrawer(queue: @queue) if @queue
          end
        end
      end
    end
  end
end
