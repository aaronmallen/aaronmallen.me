# frozen_string_literal: true

module Calendar
  class Slice < Hanami::Slice
    import keys: %w[operations.record_sync_outcome], from: :record

    import keys: %w[google.client], from: :google

    export %w[operations.show_calendars repos.calendar_queries]
  end
end
