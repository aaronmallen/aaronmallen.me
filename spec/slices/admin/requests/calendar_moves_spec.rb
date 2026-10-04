# frozen_string_literal: true

RSpec.describe "Admin calendar moves", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:today) { Blog::TimeZone.today }

  def at(date, hour, minute = 0) = Blog::TimeZone.local_time(date.year, date.month, date.day, hour, minute)

  def day = today + 3

  def form(to, from) = { _csrf_token: admin_csrf_token, to: to.to_s, day: from.to_s }

  def move(kind, record, to, from: day) = post("/admin/calendar/#{kind}/#{record.id}/move", form(to, from))

  def panel = page.find("[data-calendar-panel]")

  def stored_post(post) = Posts::Slice["repos.post_repo"].by_id(post.id)

  def stored_social(social_post) = Social::Slice["repos.social_post_repo"].by_id(social_post.id)

  def target = today + 10

  def toast = page.find("[data-toast]", visible: :all).text(:all)

  it "moves nothing for anybody who has not signed in" do
    scheduled = create(:post, :scheduled, published_at: at(day, 9))
    post "/admin/calendar/posts/#{scheduled.id}/move", to: target.iso8601, day: day.iso8601

    expect(stored_post(scheduled).published_at).to eq(scheduled.published_at)
  end

  describe "signed in" do
    let(:scheduled) { create(:post, :scheduled, title: "Spread me out", published_at: at(day, 9, 15)) }
    let(:queued) { create(:social_post, :scheduled, posted_at: at(day, 16, 45)) }

    before { sign_in_to_admin }

    describe "the day panel" do
      before do
        scheduled
        queued
        create(:post, :published, title: "Out already", published_at: at(today, 0))
        create(:social_post, :posted, posted_at: at(today, 0))
      end

      it "offers a move form on a scheduled post and a scheduled social post" do
        get "/admin/calendar", day: day.iso8601

        expect(panel.all("form.cal-move").map { it[:action] }).to eq(
          ["/admin/calendar/posts/#{scheduled.id}/move", "/admin/calendar/social/#{queued.id}/move"],
        )
      end

      it "names each move field and starts it on the day with today as the floor" do
        get "/admin/calendar", day: day.iso8601
        field = panel.find_field("Move Spread me out to")

        expect([field[:type], field[:value], field[:min]]).to eq(["date", day.iso8601, today.iso8601])
      end

      it "shows no move form on a published post or a sent social post" do
        get "/admin/calendar", day: today.iso8601

        expect(panel).to have_no_css("form.cal-move")
      end
    end

    describe "moving a scheduled post" do
      it "changes the day it publishes and keeps its time of day" do
        move("posts", scheduled, target)

        expect(stored_post(scheduled).published_at).to eq(at(target, 9, 15))
      end

      it "keeps the post scheduled" do
        move("posts", scheduled, target)

        expect(stored_post(scheduled).status).to eq("scheduled")
      end

      it "returns to the day it came from, in the same month" do
        move("posts", scheduled, target)

        expect(last_response.location).to end_with("/admin/calendar?day=#{day.iso8601}")
      end

      it "says where the post went" do
        move("posts", scheduled, target)
        follow_redirect!

        expect(toast).to eq("Moved to #{target.strftime('%b %-d, %Y')} at 09:15")
      end

      it "lets the publish job pick up the new time" do
        early = create(:post, :scheduled, published_at: at(today + 1, 0))
        move("posts", early, today)
        Posts::Jobs::PublishDuePosts.new.perform

        expect(stored_post(early).status).to eq("published")
      end
    end

    describe "moving a scheduled social post" do
      it "changes the day it sends and keeps its time of day" do
        move("social", queued, target)

        expect(stored_social(queued).posted_at).to eq(at(target, 16, 45))
      end

      it "returns to the day it came from, in the same month" do
        move("social", queued, target)

        expect(last_response.location).to end_with("/admin/calendar?day=#{day.iso8601}")
      end

      it "lets the send job pick up the new time" do
        early = create(:social_post, :scheduled, posted_at: at(today + 1, 0))
        move("social", early, today)
        Social::Jobs::SendDueSocialPosts.new.perform

        expect(Social::Jobs::DeliverSocialPost.jobs.map { it["args"].first }.uniq).to eq([early.id])
      end
    end

    describe "a move to a past day" do
      it "leaves a post where it was" do
        move("posts", scheduled, today - 1)

        expect(stored_post(scheduled).published_at).to eq(scheduled.published_at)
      end

      it "leaves a social post where it was" do
        move("social", queued, today - 1)

        expect(stored_social(queued).posted_at).to eq(queued.posted_at)
      end

      it "says why" do
        move("posts", scheduled, today - 1)
        follow_redirect!

        expect(toast).to eq("A move lands on today or a day after it")
      end
    end

    it "refuses a move with no day picked" do
      move("social", queued, "")
      follow_redirect!

      expect(toast).to eq("Pick a day first")
    end

    it "refuses to move a published post" do
      published = create(:post, :published)
      move("posts", published, target)

      expect(stored_post(published).published_at).to eq(published.published_at)
    end

    it "refuses to move a sent social post" do
      sent = create(:social_post, :posted)
      move("social", sent, target)
      follow_redirect!

      expect(toast).to eq("Only a scheduled post moves")
    end

    it "refuses to move a social post that has started sending" do
      create(:social_post_delivery, :mastodon, social_post_id: queued.id)
      move("social", queued, target)

      expect(stored_social(queued).posted_at).to eq(queued.posted_at)
    end

    it "answers 404 for a post that does not exist" do
      move("posts", Data.define(:id).new(id: 999_999), target)

      expect(last_response.status).to eq(404)
    end

    it "returns to the calendar when it cannot read the day it came from" do
      move("posts", scheduled, target, from: "someday")

      expect(last_response.location).to end_with("/admin/calendar")
    end
  end
end
