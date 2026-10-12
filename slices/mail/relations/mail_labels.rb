# frozen_string_literal: true

module Mail
  module Relations
    class MailLabels < Blog::DB::Relation
      schema :mail_labels, infer: true

      def in_name_order = order(self[:name].asc)
    end
  end
end
