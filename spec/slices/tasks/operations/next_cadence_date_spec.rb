# frozen_string_literal: true

RSpec.describe Tasks::Operations::NextCadenceDate do
  let(:next_date) { Tasks::Slice["operations.next_cadence_date"] }

  def after(day, **cadence) = next_date.call(cadence, Date.parse(day)).iso8601

  describe "every N days" do
    it "counts N days from the day" do
      expect(after("2026-10-14", cadence: "days", every: 3)).to eq("2026-10-17")
    end

    it "carries into the next month" do
      expect(after("2026-10-30", cadence: "days", every: 3)).to eq("2026-11-02")
    end
  end

  describe "every N weeks on a weekday" do
    let(:fortnightly) { { cadence: "weeks", every: 2, weekday: 4, starts_on: Date.new(2026, 10, 1) } }

    it "gives the first weekday on or after the start date before the series begins" do
      expect(after("2026-09-20", **fortnightly)).to eq("2026-10-01")
    end

    it "gives the weekday after the start date when the start falls on another day" do
      expect(after("2026-09-20", **fortnightly, starts_on: Date.new(2026, 10, 5))).to eq("2026-10-08")
    end

    it "skips the off week" do
      expect(after("2026-10-01", **fortnightly)).to eq("2026-10-15")
    end

    it "keeps its weeks from the start date across months and the autumn clock change" do
      expect(after("2026-10-29", **fortnightly)).to eq("2026-11-12")
    end

    it "keeps its weeks from the start date across the year and the spring clock change" do
      expect(after("2027-03-05", **fortnightly)).to eq("2027-03-18")
    end

    it "gives next week's weekday every week" do
      expect(after("2026-10-15", **fortnightly, every: 1)).to eq("2026-10-22")
    end
  end

  describe "a day of the month" do
    it "gives this month's day when it is still ahead" do
      expect(after("2026-10-14", cadence: "month_day", day: 15)).to eq("2026-10-15")
    end

    it "gives next month's day when this month's has passed" do
      expect(after("2026-10-14", cadence: "month_day", day: 1)).to eq("2026-11-01")
    end

    it "lands the 31st on the last day of a 30-day month" do
      expect(after("2026-10-31", cadence: "month_day", day: 31)).to eq("2026-11-30")
    end

    it "lands the 31st on the last day of February" do
      expect(after("2027-01-31", cadence: "month_day", day: 31)).to eq("2027-02-28")
    end

    it "lands the 31st on the 29th of February in a leap year" do
      expect(after("2028-01-31", cadence: "month_day", day: 31)).to eq("2028-02-29")
    end

    it "returns to the 31st in a long month after a short one" do
      expect(after("2027-02-28", cadence: "month_day", day: 31)).to eq("2027-03-31")
    end
  end

  describe "the last day of the month" do
    it "gives this month's last day" do
      expect(after("2026-10-14", cadence: "month_end")).to eq("2026-10-31")
    end

    it "gives next month's last day on the last day" do
      expect(after("2026-10-31", cadence: "month_end")).to eq("2026-11-30")
    end

    it "gives the last day of February" do
      expect(after("2027-01-31", cadence: "month_end")).to eq("2027-02-28")
    end
  end

  describe "the Nth weekday of the month" do
    it "gives this month's third Wednesday" do
      expect(after("2026-10-01", cadence: "month_weekday", week: 3, weekday: 3)).to eq("2026-10-21")
    end

    it "gives next month's first Monday once this month's has passed" do
      expect(after("2026-10-14", cadence: "month_weekday", week: 1, weekday: 1)).to eq("2026-11-02")
    end

    it "gives the last Friday of the month" do
      expect(after("2026-10-14", cadence: "month_weekday", week: -1, weekday: 5)).to eq("2026-10-30")
    end

    it "gives next month's last Friday on this month's" do
      expect(after("2026-10-30", cadence: "month_weekday", week: -1, weekday: 5)).to eq("2026-11-27")
    end
  end

  describe "a fixed date each year" do
    it "gives this year's date when it is still ahead" do
      expect(after("2026-10-14", cadence: "yearly", month: 12, day: 25)).to eq("2026-12-25")
    end

    it "gives next year's date once this year's has passed" do
      expect(after("2026-10-14", cadence: "yearly", month: 3, day: 15)).to eq("2027-03-15")
    end

    it "gives next year's date on the day itself" do
      expect(after("2026-12-25", cadence: "yearly", month: 12, day: 25)).to eq("2027-12-25")
    end

    it "lands the 29th of February on the 28th outside a leap year" do
      expect(after("2026-10-14", cadence: "yearly", month: 2, day: 29)).to eq("2027-02-28")
    end

    it "keeps the 29th of February in a leap year" do
      expect(after("2027-03-01", cadence: "yearly", month: 2, day: 29)).to eq("2028-02-29")
    end
  end

  it "raises on a kind it has no branch for" do
    expect { after("2026-10-14", cadence: "hourly") }.to raise_error(ArgumentError, /hourly/)
  end
end
