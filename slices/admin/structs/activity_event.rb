# frozen_string_literal: true

module Admin
  module Structs
    class ActivityEvent < Data.define(:type, :source_id, :occurred_on, :occurred_at, :name, :name_html, :sub_line,
                                      :task_id)
      KINDS = %w[commit post journal social task comment webmention].map { Blog::Types::ActivityKind[it] }.freeze
    end
  end
end
