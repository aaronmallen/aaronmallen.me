# frozen_string_literal: true

module Admin
  module Structs
    class ActivityEvent < Data.define(:type, :source_id, :occurred_on, :occurred_at, :name, :sub_line)
      KINDS = %w[commit post journal social task webmention].map { Blog::Types::ActivityKind[it] }.freeze
    end
  end
end
