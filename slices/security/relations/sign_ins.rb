# frozen_string_literal: true

module Security
  module Relations
    class SignIns < Blog::DB::Relation
      schema :sign_ins, infer: true

      def created_before(time) = where { created_at < time }

      def newest_first = order(self[:created_at].desc, self[:id].desc)
    end
  end
end
