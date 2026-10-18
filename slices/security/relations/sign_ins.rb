# frozen_string_literal: true

module Security
  module Relations
    class SignIns < Blog::DB::Relation
      SIGNED_IN = Blog::Types::SignInOutcome["signed_in"]

      schema :sign_ins, infer: true

      def claim_failure(visitor_hashes:, since:, limit:, **row)
        transaction do
          lock_senders_until_commit(visitor_hashes)
          next unless failed.where(visitor_hash: visitor_hashes).where { created_at >= since }.count < limit

          insert(row)
        end
      end

      def created_before(time) = where { created_at < time }

      def failed = exclude(outcome: SIGNED_IN)
    end
  end
end
