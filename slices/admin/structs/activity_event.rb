# frozen_string_literal: true

module Admin
  module Structs
    class ActivityEvent < Data.define(:type, :source_id, :occurred_on, :occurred_at, :name, :name_html, :sub_line,
                                      :task_id, :decision_id)
      KINDS = Blog::Constants::ACTIVITY_SCREEN_KINDS.map { Blog::Types::ActivityKind[it] }.freeze
    end
  end
end
