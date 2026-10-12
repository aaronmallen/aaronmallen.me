# frozen_string_literal: true

module Mail
  module Relations
    class MailSettings < Blog::DB::Relation
      schema :mail_settings, infer: true

      def claim(id)
        now = Time.now

        upsert(id:, created_at: now, updated_at: now)
      end
    end
  end
end
