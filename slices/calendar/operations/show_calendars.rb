# frozen_string_literal: true

module Calendar
  module Operations
    class ShowCalendars
      PRESETS = %w[all work].freeze

      include Deps["repos.calendar_mutations", "repos.calendar_queries", google: "google.client"]

      def call(shown, preset: nil)
        ids = PRESETS.include?(preset) ? calendar_queries.listed.select { shown?(it, preset) }.map(&:id) : Array(shown)

        calendar_mutations.show(ids.filter_map { Integer(it, exception: false) })
      end

      private

      def shown?(calendar, preset) = preset == "all" || google.work?(calendar.account)
    end
  end
end
