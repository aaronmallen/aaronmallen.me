# frozen_string_literal: true

RSpec.describe "The date and time formats", type: :app do
  let(:date) { Date.new(2026, 9, 4) }
  let(:time) { Blog::TimeZone.local(Time.utc(2026, 9, 8, 2, 30)) }

  {
    full: "Friday, September 4, 2026",
    long: "September 4, 2026",
    medium: "Sep 4, 2026",
    short: "Sep 4",
    weekday: "Friday, September 4",
  }.each do |format, text|
    it "reads a date in the #{format} format as #{text}" do
      expect(Admin::Slice["i18n"].l(date, format:)).to eq(text)
    end
  end

  { clock: "21:30", day: "Sep 7, 2026", medium: "Sep 7, 2026, 21:30" }.each do |format, text|
    it "reads a Chicago time in the #{format} format as #{text}" do
      expect(Admin::Slice["i18n"].l(time, format:)).to eq(text)
    end
  end

  it "reads a date the same on the public site" do
    expect(Public::Slice["i18n"].l(date, format: :medium)).to eq("Sep 4, 2026")
  end
end
