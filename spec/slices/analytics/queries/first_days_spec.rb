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

  it "counts publish day as day one in Chicago time" do
    create(:post, :published, slug: "hello", published_at: Blog::TimeZone.day_start(today - 1) - 60)
    rolled("hello", on: today - 1, visitors: 3)

    expect(first_days("/writing/hello").fetch(:days)).to eq([0, 3, 0])
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

    it "leaves out a post published before the first rolled up day" do
      publish("older", on: today - 20)

      expect(first_days("/writing/one").fetch(:median)).to eq([4, 5, 0.5, 4])
    end

    it "leaves out a post published before the oldest raw event" do
      publish("older", on: today - 20)
      create(:analytics_event, occurred_at: Blog::TimeZone.day_start(today - 19))

      expect(first_days("/writing/one").fetch(:median)).to eq([4, 5, 0.5, 4])
    end

    it "counts a newer post nobody read as zeros" do
      publish("unread", on: today - 3)

      expect(first_days("/writing/one").fetch(:median)).to eq([3, 3.5, 0, 2])
    end

    it "reaches as far as the oldest post" do
      expect(first_days("/writing/three").fetch(:median).size).to eq(4)
    end
  end

  it "gives no median with no posts" do
    expect(first_days("/writing/hello").fetch(:median)).to eq([])
  end
end
