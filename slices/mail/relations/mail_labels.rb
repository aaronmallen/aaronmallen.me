# frozen_string_literal: true

module Mail
  module Relations
    class MailLabels < Blog::DB::Relation
      schema :mail_labels, infer: true

      def in_name_order = order(self[:name].asc)

      def store(rows)
        update = excluded(%i[name updated_at])

        dataset.insert_conflict(target: %i[mail_account_id gmail_id], update:).multi_insert(rows)
      end
    end
  end
end
