# frozen_string_literal: true

module Analytics
  module Operations
    class FindReaderWindowStart
      include Deps["settings"]

      def call(at = Time.now) = (at.to_datetime << settings.analytics[:reader_window_months]).to_time
    end
  end
end
