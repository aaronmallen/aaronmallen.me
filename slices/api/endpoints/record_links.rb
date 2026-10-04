# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module RecordLinks
      ID = { type: "integer" }.freeze
      KIND = { type: "string", enum: Blog::Types::RecordKind.values }.freeze
      UNSAVED = "could not save the change"

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

      def complaints(errors) = errors.to_h { |field, codes| [field, codes.map { reason(field, it) }] }

      def missing(kind, id) = "no #{name(kind)} has the ID #{id}"

      def name(kind) = kind.tr("_", " ")

      def reason(field, code) = COMPLAINTS.fetch(field, Blog::Constants::EMPTY_HASH).fetch(code, code)

      def summary(complaints) = complaints.map { |field, (reason)| "#{field}: #{reason}" }.join("; ")

      def unlinked(kind, id, other_kind, other_id)
        "#{name(kind)} #{id} has no link to #{name(other_kind)} #{other_id}"
      end
    end
  end
end
