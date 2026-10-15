# frozen_string_literal: true

module Search
  module Structs
    PublicHit = Data.define(:kind, :source_id, :title, :match, :day, :status, :slug, :project, :number) do
      self::MARK = "\u{E000}"
      self::UNMARK = "\u{E001}"
      self::MARKED = /#{self::MARK}(.*?)#{self::UNMARK}/m

      def excerpt = match.to_s.split(self.class::MARKED).each_with_index.map { |text, index| [text, index.odd?] }
    end
  end
end
