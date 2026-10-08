# frozen_string_literal: true

module API
  module Endpoints
    class PublishPost < Endpoint
      OUTCOME = { type: "string", enum: %w[published scheduled] }.freeze
      PUBLISHED = "blog post %s is already published"
      REPLY = Helpers::Schema.widen(Serializers::Post::SCHEMA, outcome: OUTCOME).freeze
      SCHEMA = Helpers::Schema.by_id

      include Deps[publish_draft: "posts.operations.publish_draft"]

      def handle(id:)
        case publish_draft.call(id)
          in Success[outcome, post] then Success(serialized(Serializers::Post, post).merge(outcome: outcome.to_s))
          in Failure(:not_found) then not_found(Helpers::Wording.missing("blog post", id))
          in Failure(:published) then invalid(id: [format(PUBLISHED, id)])
          in Failure[:invalid, errors] then invalid(Posts.form_complaints(errors))
          else failed(Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
