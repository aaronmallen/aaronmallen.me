# frozen_string_literal: true

module Blog
  Page = Data.define(:number, :size) do
    def self.query(number) = number == 1 ? {} : { page: number }

    def fill(rows) = Paged.new(rows: rows.first(size), number:, more: rows.size > size)

    def limit = size + 1

    def offset = (number - 1) * size

    def query = self.class.query(number)
  end
end
