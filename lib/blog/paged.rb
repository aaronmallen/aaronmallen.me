# frozen_string_literal: true

module Blog
  Paged = Data.define(:rows, :number, :more) do
    def next_number = more ? number + 1 : nil

    def past_end? = rows.empty? && number > 1

    def previous_number = number > 1 ? number - 1 : nil

    def query = Page.query(number)
  end
end
