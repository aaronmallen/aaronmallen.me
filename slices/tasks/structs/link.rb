# frozen_string_literal: true

module Tasks
  module Structs
    class Link < Data.define(:direction, :task, :type)
      BLOCKS = Blog::Types::TaskLinkType["blocks"]
      LABELS = {
        Blog::Types::TaskLinkType["parent"] => { outgoing: "parent_of", incoming: "child_of" },
        BLOCKS => { outgoing: "blocks", incoming: "blocked_by" },
        Blog::Types::TaskLinkType["duplicates"] => { outgoing: "duplicates", incoming: "duplicated_by" },
        Blog::Types::TaskLinkType["relates"] => { outgoing: "relates", incoming: "relates" },
      }.freeze
      ORDER = LABELS.keys.freeze

      def self.incoming(row) = new(direction: :incoming, task: row.from_task, type: row.type)

      def self.outgoing(row) = new(direction: :outgoing, task: row.to_task, type: row.type)

      def blocker? = direction == :incoming && type == BLOCKS && !Blog::Types::ClosedTaskStatus.valid?(task.status)

      def incoming? = direction == :incoming

      def label = LABELS.fetch(type).fetch(direction)

      def rank = [ORDER.index(type), incoming? ? 0 : 1, task.id]
    end
  end
end
