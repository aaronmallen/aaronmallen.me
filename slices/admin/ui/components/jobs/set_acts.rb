# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Jobs
        class SetActs < Component
          CONFIRMED = %w[kill delete discard].freeze
          ICONS = {
            "run" => "fa-solid fa-play", "retry" => "fa-solid fa-rotate-right", "kill" => "fa-solid fa-skull",
            "delete" => :trash, "discard" => :trash,
          }.freeze
          LABELS = "ui.components.jobs.set_acts.acts"
          WARNED = %w[delete discard].freeze

          prop :job, Blog::Types::Instance(Data)
          prop :return_to, Blog::Types::String

          def self.acts(set) = ::Activity::Repos::JobQueries::SETS.fetch(set).fetch(:acts)

          def view_template = self.class.acts(@job.set).each { act(it) }

          private

          def act(act)
            confirm = t([".confirm", act].join("."), job: @job.name) if CONFIRMED.include?(act)

            ButtonForm(
              action: path(:admin_act_on_set_job, set: @job.set, jid: @job.jid, act:), icon: ICONS.fetch(act),
              label: t([LABELS, act].join(".")), variant: (:warn if WARNED.include?(act)), morph: true, confirm:,
              hidden: { return_to: @return_to },
            )
          end
        end
      end
    end
  end
end
