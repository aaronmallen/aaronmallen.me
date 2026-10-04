# frozen_string_literal: true

RSpec.describe Analytics::Queries::WeekdayHours do
  def at(year, month, day, hour, minute) = Blog::TimeZone.local_time(year, month, day, hour, minute)

  def hours(to) = Analytics::Slice["queries.weekday_hours"].call(to:).fetch(:hours)

  describe "on the day the clocks go forward" do
    before { create(:analytics_event, occurred_at: at(2026, 3, 8, 3, 30)) }

    it "counts the event in its Chicago hour" do
      expect(hours(Date.new(2026, 3, 9))[3][6]).to eq(1)
    end
  end

  describe "on the day the clocks go back" do
    before do
      create(:analytics_event, occurred_at: Time.utc(2026, 11, 1, 6, 30))
      create(:analytics_event, occurred_at: Time.utc(2026, 11, 1, 7, 30))
    end

    it "counts both passes through 1:30 in Sunday's 1 row" do
      expect(hours(Date.new(2026, 11, 2))[1][6]).to eq(2)
    end
  end

  describe "with events before the window" do
    before { create(:analytics_event, occurred_at: at(2026, 6, 1, 12, 0)) }

    it "leaves them out" do
      expect(hours(Date.new(2026, 9, 30)).flatten.sum).to eq(0)
    end
  end
end
