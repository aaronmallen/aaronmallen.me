# frozen_string_literal: true

module Tasks
  module Structs
    class Task < Blog::DB::Struct
      OWNER = { kind: Blog::Types::ContributorKind["owner"] }.freeze

      def blocked? = links.any?(&:blocker?)

      def canceled? = status == Blog::Types::TaskStatus["canceled"]

      def closed? = Blog::Types::ClosedTaskStatus.valid?(status)

      def credits
        return [OWNER] if contributors.empty?

        contributors.map { it.agent ? { kind: it.kind, agent: it.agent, model: it.model } : OWNER }
      end

      def done? = status == Blog::Types::TaskStatus["done"]

      def in_progress? = status == Blog::Types::TaskStatus["in_progress"]

      def in_sprint? = !sprint_id.nil?

      def links = [*incoming_links.map { Link.incoming(it) }, *outgoing_links.map { Link.outgoing(it) }].sort_by(&:rank)

      def listed? = !list.nil?

      def place = list || Blog::Types::TaskFilter["today"]

      def tracked_seconds(now = Time.now)
        running_session ? worked_seconds + (now - running_session.started_at).floor : worked_seconds
      end
    end
  end
end
