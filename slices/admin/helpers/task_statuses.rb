# frozen_string_literal: true

module Admin
  module Helpers
    module TaskStatuses
      NAMES = Blog::Types::TaskStatus.values.to_h { [it, "task_statuses.#{it}"] }.freeze

      module_function

      def name(status) = NAMES.fetch(status)
    end
  end
end
