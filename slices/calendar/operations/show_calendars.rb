# frozen_string_literal: true

module Calendar
  module Operations
    class ShowCalendars
      PRESETS = { "all" => proc { true }, "work" => proc { !it.writable } }.freeze

      include Deps["repos.calendar_mutations", "repos.calendar_queries"]

      def call(shown, preset: nil)
        picked = PRESETS[preset]
        ids = picked ? calendar_queries.listed.select(&picked).map(&:id) : Array(shown)

        calendar_mutations.show(ids.filter_map { Integer(it, exception: false) })
      end
    end
  end
end
