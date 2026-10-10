# frozen_string_literal: true

module Activity
  module Relations
    class Attention < Blog::DB::Relation
      BROKEN_LINK = Blog::Types::AttentionKind["broken_link"]
      CARRIED = Blog::Types::AttentionKind["carried"]
      DRAFT = Blog::Types::AttentionKind["draft"]
      JOURNAL = Blog::Types::AttentionKind["journal"]
      NEW_DEVICE = Blog::Types::AttentionKind["new_device"]
      SOMEDAY = Blog::Types::AttentionKind["someday"]
      ROWS = Sequel[:attention]
      SNOOZES = Sequel[:attention_snoozes]
      SNOOZED_ROW = Sequel[SNOOZES[:kind].cast(:text) => ROWS[:kind]] &
                    Sequel.lit("? IS NOT DISTINCT FROM ?", SNOOZES[:record_id], ROWS[:record_id])

      schema :attention, infer: true

      def stalled(
        on:, now:, broken_link_failures:, carried_count:, draft_days:, journal_days:, new_device_days:, someday_days:
      )
        where(
          Sequel.|(
            failing(broken_link_failures),
            carried(carried_count),
            seen_since(NEW_DEVICE, on - new_device_days),
            untouched(DRAFT, on - draft_days),
            untouched(JOURNAL, on - journal_days),
            untouched(SOMEDAY, on - someday_days),
          ),
        ).exclude(snoozed(now))
      end

      private

      def carried(count) = Sequel[kind: CARRIED] & (Sequel[:carried_count] >= count)

      def failing(count) = Sequel[kind: BROKEN_LINK] & (Sequel[:failures] >= count)

      def seen_since(kind, since) = Sequel[kind:] & (Sequel[:touched_on] > since)

      def snoozed(now) = dataset.db[:attention_snoozes].where(SNOOZED_ROW & (SNOOZES[:ends_at] > now)).exists

      def untouched(kind, since) = Sequel[kind:] & (Sequel[:touched_on] <= since)
    end
  end
end
