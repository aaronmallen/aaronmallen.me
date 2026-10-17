# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class FieldError < Blog::UI::FieldError
          CONTRACTS = [
            ::Tasks::Contracts::TaskCadenceContract,
            ::Tasks::Contracts::TaskCommentContract,
            ::Tasks::Contracts::TaskContract,
            ::Tasks::Contracts::TaskLinkContract,
            ::Tasks::Contracts::WorkSessionContract,
            ::Tasks::Contracts::WorkedContract,
          ].freeze
          SCOPE = "task"
          UNSHOWN = %i[tracked].freeze

          def self.field_slug(field) = super.tr("_", "-")
        end
      end
    end
  end
end
