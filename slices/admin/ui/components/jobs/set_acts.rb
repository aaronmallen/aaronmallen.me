# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Jobs
        class SetActs < Component
          ACTS = ::Activity::Operations::ActOnSetJob::ACTS
          CONFIRMS = %w[kill delete discard].to_h { [it, ".confirm.#{it}"] }.freeze
          ICONS = {
            "run" => "fa-solid fa-play", "retry" => "fa-solid fa-rotate-right", "kill" => "fa-solid fa-skull",
            "delete" => :trash, "discard" => :trash,
          }.freeze
          LABELS = ICONS.keys.to_h { [it, ".#{it}"] }.freeze
          WARNED = %w[delete discard].freeze

          prop :job, Blog::Types::Instance(Data)
          prop :return_to, Blog::Types::String

          def view_template = ACTS.fetch(@job.set).each { act(it) }

          private

          def act(act)
            ButtonForm(
              action: path(:admin_act_on_set_job, set: @job.set, jid: @job.jid, act:), label: t(LABELS.fetch(act)),
              icon: ICONS.fetch(act), variant: (:warn if WARNED.include?(act)), morph: true,
              confirm: (t(CONFIRMS[act], job: @job.name) if CONFIRMS.key?(act)), hidden: { return_to: @return_to },
            )
          end
        end
      end
    end
  end
end
