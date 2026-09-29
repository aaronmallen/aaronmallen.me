# frozen_string_literal: true

RSpec.describe Blog::DayCursor do
  let(:first) { Date.new(2026, 3, 1) }
  let(:last) { Date.new(2026, 3, 31) }

  def page(rows, size:, from: first)
    described_class.page(from, last, size:, day: :itself.to_proc) do |low, high, limit|
      found = rows.grep(low..high)
      limit ? found.first(limit) : found
    end
  end

  def rows_on(*days) = days.map { Date.new(2026, 3, it) }.sort.reverse

  it "answers every row when they fit in one page", :aggregate_failures do
    result = page(rows_on(1, 2, 3), size: 3)

    expect(result.rows).to eq(rows_on(1, 2, 3))
    expect(result).not_to be_partial
  end

  it "stops near the size and finishes the day it is on", :aggregate_failures do
    result = page(rows_on(1, 2, 2, 2, 3), size: 2)

    expect(result.rows).to eq(rows_on(2, 2, 2, 3))
    expect(result.continue_to).to eq(Date.new(2026, 3, 1))
  end

  it "points past the gap to the day before the last one it answered" do
    result = page(rows_on(1, 5, 6), size: 1)

    expect(result.continue_to).to eq(Date.new(2026, 3, 5))
  end

  it "is not partial when the last day holds the rest of the window", :aggregate_failures do
    result = page(rows_on(2, 2, 2), size: 2)

    expect(result.rows).to eq(rows_on(2, 2, 2))
    expect(result).not_to be_partial
  end

  it "is not partial when the page ends on the first day of the window" do
    result = page(rows_on(1, 1, 2), size: 2)

    expect(result).not_to be_partial
  end
end
