# frozen_string_literal: true

RSpec.describe "Admin calendar moves", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:today) { Blog::TimeZone.today }

  def at(date, hour, minute = 0) = Blog::TimeZone.local_time(date.year, date.month, date.day, hour, minute)

  def clock(hour) = allow(Time).to receive(:now).and_return(at(today, hour))

  def day = today + 3

  def form(to, from) = { _csrf_token: admin_csrf_token, to: to.to_s, day: from.to_s }

  def move(kind, record, to, from: day) = post("/admin/calendar/#{kind}/#{record.id}/move", form(to, from))

  def panel = page.find("[data-calendar-panel]")

  def stored_post(post) = Posts::Slice["repos.post_queries"].by_id(post.id)

  def stored_social(social_post) = Social::Slice["repos.social_post_queries"].by_id(social_post.id)

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
    end

    describe "a move to today" do
      before do
        clock(12)
        connect_social_networks
      end

      it "moves a post to a time still ahead" do
        later = create(:post, :scheduled, published_at: at(day, 15))
        move("posts", later, today)

        expect(stored_post(later).published_at).to eq(at(today, 15))
      end

      it "moves a social post to a time still ahead" do
        later = create(:social_post, :scheduled, posted_at: at(day, 15))
        move("social", later, today)

        expect(stored_social(later).posted_at).to eq(at(today, 15))
      end

      it "lets the publish job pick up the new time" do
        early = create(:post, :scheduled, published_at: at(today + 1, 13))
        move("posts", early, today)
        clock(13)
        Posts::Jobs::PublishDuePosts.new.perform

        expect(stored_post(early).status).to eq("published")
      end

      it "lets the send job pick up the new time" do
        early = create(:social_post, :scheduled, posted_at: at(today + 1, 13))
        move("social", early, today)
        clock(13)
        Social::Jobs::SendDueSocialPosts.new.perform

        expect(Social::Jobs::DeliverSocialPost.jobs.map { it["args"].first }.uniq).to eq([early.id])
      end

      it "leaves a post where it was when its time has gone" do
        move("posts", scheduled, today)

        expect(stored_post(scheduled).published_at).to eq(scheduled.published_at)
      end

      it "leaves a social post where it was when its time has gone" do
        early = create(:social_post, :scheduled, posted_at: at(day, 9))
        move("social", early, today)

        expect(stored_social(early).posted_at).to eq(early.posted_at)
      end

      it "keeps the publish job from picking up a post it refused" do
        move("posts", scheduled, today)
        Posts::Jobs::PublishDuePosts.new.perform

        expect(stored_post(scheduled).status).to eq("scheduled")
      end

      it "keeps the send job from picking up a social post it refused" do
        move("social", create(:social_post, :scheduled, posted_at: at(day, 9)), today)
        Social::Jobs::SendDueSocialPosts.new.perform

        expect(Social::Jobs::DeliverSocialPost.jobs).to be_empty
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

  describe "moving a sprint task" do
    let(:sprint) { create(:sprint, sprint_date: day) }
    let(:task) { create(:task, :in_sprint, sprint_id: sprint.id, title: "Lighten the day") }

    before { sign_in_to_admin }

    def sprint_on(record) = Tasks::Slice["repos.sprint_queries"].by_id(stored_task(record).sprint_id).sprint_date

    def stored_task(record) = Tasks::Slice["repos.task_queries"].by_id(record.id)

    it "offers a move form on each open task in the day's sprint and none on a closed one" do
      task
      create(:task, :in_sprint, :done, sprint_id: sprint.id)
      create(:task, :in_sprint, :canceled, sprint_id: sprint.id)
      get "/admin/calendar", day: day.iso8601

      expect(panel.all("form.cal-move").map { it[:action] }).to eq(["/admin/calendar/tasks/#{task.id}/move"])
    end

    it "names the move field and starts it on the day with today as the floor" do
      task
      get "/admin/calendar", day: day.iso8601
      field = panel.find_field("Move Lighten the day to")

      expect([field[:type], field[:value], field[:min]]).to eq(["date", day.iso8601, today.iso8601])
    end

    it "puts the task in the sprint already on that day" do
      planned = create(:sprint, sprint_date: target)
      move("tasks", task, target)

      expect(stored_task(task).sprint_id).to eq(planned.id)
    end

    it "plans a sprint for a day that has none and puts the task in it" do
      move("tasks", task, target)

      expect(sprint_on(task)).to eq(target)
    end

    it "returns to the day it came from, in the same month" do
      move("tasks", task, target)

      expect(last_response.location).to end_with("/admin/calendar?day=#{day.iso8601}")
    end

    it "says where the task went" do
      move("tasks", task, target)
      follow_redirect!

      expect(toast).to eq("Moved to the #{target.strftime('%b %-d, %Y')} sprint")
    end

    it "shows the move on the task's timeline" do
      move("tasks", task, target)
      get "/admin/tasks/#{task.id}", filter: "next"
      dates = [day, target].map { "the #{it.strftime('%b %-d, %Y')} sprint" }

      expect(page).to have_css(".timeline-event", text: "Moved from #{dates.first} to #{dates.last}")
    end

    it "leaves a task where it was on a move to a past day, and says why", :aggregate_failures do
      move("tasks", task, today - 1)
      follow_redirect!

      expect(stored_task(task).sprint_id).to eq(sprint.id)
      expect(toast).to eq("A move lands on today or a day after it")
    end

    it "leaves a task in its sprint when no day is picked", :aggregate_failures do
      move("tasks", task, "")
      follow_redirect!

      expect(stored_task(task).sprint_id).to eq(sprint.id)
      expect(toast).to eq("Pick a day first")
    end

    it "leaves a done task where it closed", :aggregate_failures do
      done = create(:task, :in_sprint, :done, sprint_id: sprint.id)
      move("tasks", done, target)
      follow_redirect!

      expect(stored_task(done).sprint_id).to eq(sprint.id)
      expect(toast).to eq("A closed task stays where it closed")
    end

    it "answers 404 for a task that does not exist" do
      move("tasks", Data.define(:id).new(id: 999_999), target)

      expect(last_response.status).to eq(404)
    end
  end
end
