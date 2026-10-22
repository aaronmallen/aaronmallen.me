# frozen_string_literal: true

module API
  module Endpoints
    class MakeMailTask < TaskEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          archive: {
            type: "boolean", description: "archives the thread once the task is made; true when you leave it out",
          },
          id: Helpers::Schema::ID,
          list: {
            type: "string",
            enum: Tasks::LISTS,
            description: "today puts it in today's sprint; next when you leave it out",
          },
          title: { type: "string", description: "the task" },
        },
        required: %w[id title],
      }.freeze

      REPLY = Helpers::Schema.widen(TaskEndpoint::REPLY, archived: Helpers::Schema::BOOLEAN).freeze

      include Deps[make_mail_task: "operations.make_mail_task"]

      def handle(id:, title:, list: Blog::Types::TaskFilter["next"], archive: true)
        case make_mail_task.call(id, { title: }, filter: list, archive:)
          in Success(task) then answered(task.id, archived: archive)
          in Failure[:unarchived, task] then answered(task.id, archived: false)
          in Failure(:not_found) then missing("mail thread", id)
          in Failure(:tasked) then invalid(id: ["mail thread #{id} already has a task"])
          in Failure[:invalid, errors] then rejected(errors, Tasks::COMPLAINTS)
          in unmatched then unhandled(unmatched, Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
