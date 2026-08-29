# frozen_string_literal: true

module Social
  module Relations
    class WebmentionSettings < Blog::DB::Relation
      schema :webmention_settings, infer: true

      def claim(id)
        now = Time.now

        upsert(id:, created_at: now, updated_at: now)
      end
    end
  end
end
