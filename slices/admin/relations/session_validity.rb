# frozen_string_literal: true

module Admin
  module Relations
    class SessionValidity < Blog::DB::Relation
      schema :session_validity, infer: true

      def end_sessions(id, at)
        update = { valid_after: at, updated_at: at }

        upsert({ id:, valid_after: at, created_at: at, updated_at: at }, target: :id, update:)
      end
    end
  end
end
