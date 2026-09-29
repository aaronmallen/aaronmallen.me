# frozen_string_literal: true

module Blog
  module DayCursor
    Page = Data.define(:rows, :continue_to) do
      def partial? = !continue_to.nil?
    end

    module_function

    def next_day(first, boundary)
      boundary - 1 if boundary > first && yield(first, boundary - 1, 1).any?
    end
    private_class_method :next_day

    def page(first, last, size:, day:, &)
      head = yield(first, last, size + 1)
      return Page.new(rows: head, continue_to: nil) if head.length <= size

      boundary = day.call(head[size - 1])
      rows = head.take_while { day.call(it) > boundary } + yield(boundary, boundary, nil)

      Page.new(rows:, continue_to: next_day(first, boundary, &))
    end
  end
end
