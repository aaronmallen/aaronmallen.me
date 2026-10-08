# frozen_string_literal: true

module Admin
  module Structs
    class ActivityEvent < Data.define(:type, :source_id, :occurred_on, :occurred_at, :name, :name_html, :sub_line,
                                      :task_id, :decision_id)
      KINDS = Blog::Types::ActivityScreenKind.values
    end
  end
end
