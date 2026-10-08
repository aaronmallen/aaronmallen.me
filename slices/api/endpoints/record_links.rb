# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module RecordLinks
      ID = Helpers::Schema::ID
      KIND = { type: "string", enum: Blog::Types::RecordKind.values }.freeze

      COMPLAINTS = {
        other_id: {
          Blog::Contract::FORMAT => "pick a record by its ID",
          "missing" => "that record is gone, so find another",
          "self" => "a record cannot link to itself",
          "taken" => "these two records are already linked",
          "task_pair" => "two tasks take link_tasks, which gives the link a type",
        },
        other_kind: { Blog::Contract::FORMAT => "pick one of the eight kinds" },
      }.freeze

      module_function

      def name(kind) = kind.tr("_", " ")

      def unlinked(kind, id, other_kind, other_id)
        "#{name(kind)} #{id} has no link to #{name(other_kind)} #{other_id}"
      end
    end
  end
end
