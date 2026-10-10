# frozen_string_literal: true

RSpec.describe Blog::TimeZone do
  describe ".day_bounds" do
    it "runs from the first day's local midnight to the midnight after the last day" do
      expect(described_class.day_bounds(Date.new(2026, 3, 1), Date.new(2026, 3, 31)))
        .to eq([described_class.local_time(2026, 3, 1), described_class.local_time(2026, 4, 1)])
    end

    it "ends the day the clocks spring forward 23 hours after it starts" do
      first, last = described_class.day_bounds(Date.new(2026, 3, 8), Date.new(2026, 3, 8))

      expect(last - first).to eq(23 * 3600)
    end

    it "leaves an open end open", :aggregate_failures do
      expect(described_class.day_bounds(nil, Date.new(2026, 3, 1))).to eq([nil, described_class.local_time(2026, 3, 2)])
      expect(described_class.day_bounds(Date.new(2026, 3, 1), nil)).to eq([described_class.local_time(2026, 3, 1), nil])
    end
  end
end
