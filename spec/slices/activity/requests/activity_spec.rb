# frozen_string_literal: true

RSpec.describe "Activity", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:today) { Blog::TimeZone.today }
  let(:yesterday) { today - 1 }

  def at(hour, minute = 0, on: today) = Blog::TimeZone.local_time(on.year, on.month, on.day, hour, minute)

  def count_for(icon) = page.find(".activity-type:has(.fa-#{icon}) .activity-type-count").text

  def day_names(date)
    page.all(".activity-day:has(time[datetime='#{date.iso8601}']) .activity-event-name").map(&:text)
  end

  def event_names = page.all(".activity-event-name").map(&:text)

  def visit_activity(params = {}) = get("/admin/activity", params)

  before { sign_in_to_admin }

  describe "what has yet to happen" do
    it "leaves a draft post out" do
      create(:post, :draft, title: "Half done")
      visit_activity

      expect(event_names).to be_empty
    end

    it "leaves a scheduled post out" do
      create(:post, :scheduled, title: "Soon")
      visit_activity(to: (today + 7).iso8601)

      expect(event_names).to be_empty
    end

    it "leaves a draft social post out" do
      create(:social_post, :draft)
      visit_activity

      expect(event_names).to be_empty
    end

    it "leaves a scheduled social post out" do
      create(:social_post, :scheduled)
      visit_activity(to: (today + 7).iso8601)

      expect(event_names).to be_empty
    end
  end

  describe "a webmention under review" do
    let(:post) { create(:post, :published, slug: "hello") }

    def mention(*traits, author:)
      create(
        :webmention, *traits,
        post_id: post.id, author_name: author, excerpt: "#{author} says hi", received_at: at(8),
      )
    end

    before do
      mention(:approved, author: "Ada")
      mention(author: "Pending")
      mention(:spam, author: "Buy now")
    end

    it "shows only the approved one" do
      visit_activity(types: { webmention: "1" })

      expect(event_names).to eq(["Ada"])
    end

    it "counts only the approved one" do
      visit_activity

      expect(count_for("at")).to eq("1")
    end

    it "finds none but the approved one by its text", :aggregate_failures do
      visit_activity(q: "pending says")
      expect(event_names).to be_empty

      visit_activity(q: "buy now")
      expect(event_names).to be_empty
    end
  end

  describe "the day an event lands on" do
    it "reads a post published just before midnight in Chicago as that day" do
      create(:post, :published, title: "Late", published_at: at(23, 59, on: yesterday))
      visit_activity

      expect(day_names(yesterday)).to eq(["Late"])
    end

    it "reads a post published at 00:30 UTC as the day before in Chicago" do
      create(:post, :published, title: "Early", published_at: Time.utc(today.year, today.month, today.day, 0, 30))
      visit_activity

      expect(day_names(yesterday)).to eq(["Early"])
    end
  end

  describe "searching" do
    it "takes a percent sign as text, not a wildcard" do
      create(:commit, commit_date: today, message: "100% done")
      create(:commit, commit_date: today, message: "nothing to see")
      visit_activity(q: "0% d")

      expect(event_names).to eq(["100% done"])
    end

    it "matches no repo when the query names only its owner" do
      create(:commit, repo: "aaronmallen/one", commit_date: today, message: "in one")
      visit_activity(q: "repo:aaronmallen")

      expect(event_names).to be_empty
    end
  end
end
