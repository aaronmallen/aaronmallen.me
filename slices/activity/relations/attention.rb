# frozen_string_literal: true

module Activity
  module Relations
    class Attention < Blog::DB::Relation
      CARRIED = Blog::Types::AttentionKind["carried"]
      DRAFT = Blog::Types::AttentionKind["draft"]
      JOURNAL = Blog::Types::AttentionKind["journal"]
      SOMEDAY = Blog::Types::AttentionKind["someday"]
      ROWS = Sequel[:attention]
      SNOOZES = Sequel[:attention_snoozes]
      SNOOZED_ROW = Sequel[SNOOZES[:kind].cast(:text) => ROWS[:kind]] &
                    Sequel.lit("? IS NOT DISTINCT FROM ?", SNOOZES[:record_id], ROWS[:record_id])

      schema :attention, infer: true

      def stalled(on:, now:, carried_count:, draft_days:, journal_days:, someday_days:)
        where(
          Sequel.|(
            carried(carried_count),
            untouched(DRAFT, on - draft_days),
            untouched(JOURNAL, on - journal_days),
            untouched(SOMEDAY, on - someday_days),
          ),
        ).exclude(snoozed(now))
      end

      private

      def carried(count) = Sequel[kind: CARRIED] & (Sequel[:carried_count] >= count)

      def snoozed(now) = dataset.db[:attention_snoozes].where(SNOOZED_ROW & (SNOOZES[:ends_at] > now)).exists

      def untouched(kind, since) = Sequel[kind:] & (Sequel[:touched_on] <= since)
    end
  end
end
