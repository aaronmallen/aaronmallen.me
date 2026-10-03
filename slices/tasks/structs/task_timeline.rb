# frozen_string_literal: true

module Tasks
  module Structs
    class TaskTimeline < Blog::DB::Struct
      def comment? = kind == Blog::Types::TaskTimelineKind["comment"]

      def running? = session? && ended_at.nil?

      def seconds = ((ended_at || Time.now) - occurred_at).floor

      def session? = kind == Blog::Types::TaskTimelineKind["session"]

      def synced? = !remote_id.nil?
    end
  end
end
