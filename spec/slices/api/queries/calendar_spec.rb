# frozen_string_literal: true

RSpec.describe API::Queries::Calendar do
  it "refuses a range that ends before it starts" do
    first = Date.new(2026, 10, 5)

    expect(API::Slice["queries.calendar"].call(from: first, to: first - 1))
      .to eq(Dry::Monads::Failure(Blog::DayWindow::BACKWARDS))
  end
end
