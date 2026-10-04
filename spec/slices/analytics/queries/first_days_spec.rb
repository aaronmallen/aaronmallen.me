# frozen_string_literal: true

RSpec.describe Analytics::Queries::FirstDays do
  let(:today) { Blog::TimeZone.today }

  def first_days(path) = Analytics::Slice["queries.first_days"].call(path)

  def publish(slug, on:, status: "published")
    create(:post, slug:, status:, published_at: Blog::TimeZone.day_start(on) + (12 * 3_600))
  end

  def rolled(slug, on:, visitors:)
    path = "/writing/#{slug}"

    create(:analytics_rollup_path, day: rolled_day(on), path:, views: visitors, visitors:, bounces: 0)
  end

  def rolled_day(on) = (@rolled_days ||= {})[on] ||= create(:analytics_rollup, day: on).day

  it "counts readers per day for the first 30 days, leaving out the days after" do
    publish("hello", on: today - 40)
    rolled("hello", on: today - 40, visitors: 9)
    rolled("hello", on: today - 11, visitors: 4)
    rolled("hello", on: today - 10, visitors: 7)

    expect(first_days("/writing/hello").fetch(:days)).to eq([9, *Array.new(28, 0), 4])
  end

  it "counts a day nobody read as zero" do
    publish("hello", on: today - 2)
    rolled("hello", on: today - 2, visitors: 5)

    expect(first_days("/writing/hello").fetch(:days)).to eq([5, 0, 0])
  end

  it "draws as many days as a young post has had" do
    publish("hello", on: today - 9)

    expect(first_days("/writing/hello").fetch(:days).size).to eq(10)
  end

  it "counts publish day as day one in Chicago time" do
    create(:post, :published, slug: "hello", published_at: Blog::TimeZone.day_start(today - 1) - 60)
    rolled("hello", on: today - 1, visitors: 3)

    expect(first_days("/writing/hello").fetch(:days)).to eq([0, 3, 0])
  end

  it "reads today live beside the rolled up days" do
    publish("hello", on: today - 1)
    rolled("hello", on: today - 1, visitors: 6)
    2.times { create(:analytics_event, path: "/writing/hello") }

    expect(first_days("/writing/hello").fetch(:days)).to eq([6, 2])
  end

  it "gives no days for a draft" do
    publish("hello", on: today, status: "draft")

    expect(first_days("/writing/hello").fetch(:days)).to eq([])
  end

  it "spans 30 days" do
    expect(first_days("/writing/hello").fetch(:span)).to eq(30)
  end

  describe "the median" do
    before do
      publish("one", on: today - 3)
      publish("two", on: today - 2)
      publish("three", on: today - 1)
      { "one" => [2, 8, 1, 4], "two" => [6, 2, 0], "three" => [4, 5] }.each do |slug, counts|
        start = today - (counts.size - 1)
        counts.each_with_index { |visitors, index| rolled(slug, on: start + index, visitors:) unless visitors.zero? }
      end
    end

    it "takes the middle count of every post old enough for each day" do
      expect(first_days("/writing/one").fetch(:median)).to eq([4, 5, 0.5, 4])
    end

    it "leaves out drafts" do
      publish("draft", on: today - 3, status: "draft")
      rolled("draft", on: today - 3, visitors: 100)

      expect(first_days("/writing/one").fetch(:median).first).to eq(4)
    end

    it "reaches as far as the oldest post" do
      expect(first_days("/writing/three").fetch(:median).size).to eq(4)
    end
  end

  it "gives no median with no posts" do
    expect(first_days("/writing/hello").fetch(:median)).to eq([])
  end
end
