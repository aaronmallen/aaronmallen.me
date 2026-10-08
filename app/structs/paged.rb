# frozen_string_literal: true

module Blog
  module Structs
    Paged = Data.define(:rows, :number, :more) do
      def newer_query = previous_number && Page.query(previous_number)

      def next_number = more ? number + 1 : nil

      def older_query = next_number && Page.query(next_number)

      def past_end? = rows.empty? && number > 1

      def previous_number = number > 1 ? number - 1 : nil

      def query = Page.query(number)
    end
  end
end
