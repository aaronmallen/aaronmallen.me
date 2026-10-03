# frozen_string_literal: true

module Activity
  module Relations
    class Attention < Blog::DB::Relation
      CARRIED = Blog::Types::AttentionKind["carried"]
      DRAFT = Blog::Types::AttentionKind["draft"]
      JOURNAL = Blog::Types::AttentionKind["journal"]
      SOMEDAY = Blog::Types::AttentionKind["someday"]

      schema :attention, infer: true

      def stalled(on:, carried_count:, draft_days:, journal_days:, someday_days:)
        where(
          Sequel.|(
            carried(carried_count),
            untouched(DRAFT, on - draft_days),
            untouched(JOURNAL, on - journal_days),
            untouched(SOMEDAY, on - someday_days),
          ),
        )
      end

      private

      def carried(count) = Sequel[kind: CARRIED] & (Sequel[:carried_count] >= count)

      def untouched(kind, since) = Sequel[kind:] & (Sequel[:touched_on] <= since)
    end
  end
end
