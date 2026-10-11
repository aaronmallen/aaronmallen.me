# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Health
        class Workout < Component
          ICONS = {
            "BIKING" => "fa-person-biking", "RUNNING" => "fa-person-running", "STRENGTH_TRAINING" => "fa-dumbbell",
            "WALKING" => "fa-person-walking", "YOGA" => "fa-spa",
          }.freeze
          DECIMAL = "%g"
          ICON = "fa-heart-pulse"
          KILOMETER = 1000.0

          prop :workout, Blog::Types::Instance(ROM::Struct)

          def view_template
            div(class: "health-workout") do
              Icon(["fa-solid", ICONS.fetch(@workout.kind, ICON)])
              div do
                p(class: "health-workout-name") { dotted(kind, distance) }
                p(class: "meta") { sub }
              end
              span(class: "meta") { l(Blog::TimeZone.local(@workout.started_at), format: :clock) }
            end
          end

          private

          def distance
            meters = @workout.distance_meters
            t(".km", count: format(DECIMAL, (meters / KILOMETER).round(1))) if meters&.positive?
          end

          def kind = @workout.kind.tr("_", " ").capitalize

          def sub
            dotted(
              Blog::Helpers::Figures.minutes(@workout.minutes),
              (t(".heart_rate", count: @workout.average_heart_rate) if @workout.average_heart_rate),
              (t(".zone_minutes", count: @workout.zone_minutes) if @workout.zone_minutes&.positive?),
              (t(".kcal", count: @workout.kcal) if @workout.kcal),
              @workout.device,
            )
          end
        end
      end
    end
  end
end
