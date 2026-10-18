# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Jobs
        class Warnings < Component
          prop :health, Blog::Types::Instance(Data)

          def view_template
            return redis_down if @health.down?

            worker_gone if @health.status == :not_seen
          end

          private

          def finished
            at = @health.last_job_at
            return t(".no_job") unless at

            t(".last_job", ago: Blog::Helpers::Figures.elapsed(Time.now - at))
          end

          def redis_down
            div(class: "post-banner jobs-banner", role: "alert") do
              Icon("fa-solid fa-plug-circle-xmark")
              span(class: "post-banner-text") do
                plain t(".redis")
                span(class: "jobs-raw") { @health.error }
              end
              Button(href: path(:admin_settings_jobs), small: true, icon: "fa-solid fa-rotate") { t(".again") }
            end
          end

          def worker_gone
            waiting = @health.enqueued

            div(class: "post-banner jobs-banner", role: "alert") do
              Icon("fa-solid fa-heart-crack")
              span(class: "post-banner-text") do
                plain [t(".no_worker"), finished, t(".waiting", count: waiting, formatted: count(waiting))].join(" ")
              end
            end
          end
        end
      end
    end
  end
end
