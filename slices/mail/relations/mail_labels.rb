# frozen_string_literal: true

module Mail
  module Relations
    class MailLabels < Blog::DB::Relation
      schema :mail_labels, infer: true
    end
  end
end
