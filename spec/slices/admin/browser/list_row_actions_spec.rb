# frozen_string_literal: true

RSpec.describe "Admin list row actions", type: :feature do
  def keep_page = execute_script("window.kept = true")

  def kept_page? = evaluate_script("window.kept === true")

  def morning(day) = Blog::TimeZone.local_time(day.year, day.month, day.day, 9)

  def translate(key, **) = Admin::Slice["i18n"].t(key, **)

  before { sign_in_to_admin }

  shared_examples "a row action in place" do |toast|
    before do
      visit screen
      keep_page
      act
    end

    it "updates the page in place and shows the toast", :aggregate_failures do
      expect(page).to have_css(".toast:not(.toast-failed)", text: toast)
      expect(page).to have_no_css("dialog[open]")
      expect(kept_page?).to be(true)
    end
  end

  describe "the inbox" do
    let(:screen) { "/admin/inbox" }

    def row(text) = find(".inbox-row", text:).tap(&:hover)

    describe "moving an issue" do
      before { create(:task, title: "Fix the feed", list: "external").tap { create(:task_source, task: it) } }

      def act = row("Fix the feed").click_button(translate("task_lists.titles.someday"))

      it_behaves_like "a row action in place", "Moved"
    end

    describe "marking an issue seen" do
      before { create(:task, title: "Fix the feed", list: "external").tap { create(:task_source, task: it) } }

      def act = row("Fix the feed").click_button("Seen")

      it_behaves_like "a row action in place", "Marked seen"
    end

    describe "marking a message read" do
      before { create(:message, subject: "Hello there") }

      def act = row("Hello there").click_button("Read")

      it_behaves_like "a row action in place", "Marked read"
    end

    describe "approving a webmention" do
      before { create(:webmention, author_name: "Ada") }

      def act = row("Ada").click_button("Approve")

      it_behaves_like "a row action in place", "Approved"
    end

    describe "snoozing a message" do
      before { create(:message, subject: "Hello there") }

      def act
        row("Hello there").click_button("Snooze")
        find("dialog[open]").click_button("Tomorrow morning")
      end

      it_behaves_like "a row action in place", "Snoozed until"
    end

    describe "waking a snoozed message" do
      before do
        message = create(:message, subject: "Hello there")
        Mail::Slice["operations.snooze_messages"].call([message.id], Time.now + 3600)
      end

      def act
        find("#inbox-snoozed summary").click
        find(".inbox-snoozed-row", text: "Hello there").click_button("Wake now")
      end

      it_behaves_like "a row action in place", "Back in the inbox"
    end
  end

  describe "the posts list" do
    let(:screen) { "/admin/posts?status=draft" }

    before { create(:post, :draft, title: "Fresh draft") }

    def act = find(".li", text: "Fresh draft").tap(&:hover).click_button("Publish Fresh draft")

    it_behaves_like "a row action in place", "Published"
  end

  describe "an open mail thread" do
    let(:thread) { create(:message, subject: "Hello there") }
    let(:screen) { "/admin/mail?thread=#{thread.id}" }

    def letter = find(".mail-reader")

    describe "marking it read" do
      def act = letter.click_button("Mark read")

      it_behaves_like "a row action in place", "Marked read"
    end

    describe "snoozing it" do
      def act
        letter.click_button("Snooze")
        find("dialog[open]").click_button("Tomorrow morning")
      end

      it_behaves_like "a row action in place", "Snoozed until"
    end

    describe "deleting it" do
      def act = confirm_yes { letter.click_button("Delete") }

      it_behaves_like "a row action in place", "Thread deleted"
    end
  end

  describe "the calendar" do
    let(:day) { today + 2 }
    let(:screen) { "/admin/calendar?day=#{day.iso8601}" }

    before { create(:post, :scheduled, title: "Spread me out", published_at: morning(day)) }

    def act
      find_field("Move Spread me out to").set((day + 1).iso8601)
      click_button("Move")
    end

    it_behaves_like "a row action in place", "Moved to"
  end

  describe "the webmentions list" do
    let(:screen) { "/admin/webmentions" }

    before { create(:webmention, author_name: "Ada") }

    def act = find(".wm-card", text: "Ada").tap(&:hover).click_button("Approve")

    it_behaves_like "a row action in place", "Approved"
  end

  describe "the links list" do
    let(:screen) { "/admin/links" }

    before { Shares::Slice["operations.create_short_link"].call({ destination: "https://example.com/talk", code: "talk" }) }

    def act
      find(".link-row-title a").click
      confirm_yes { find("dialog[open]").click_button("Delete link") }
    end

    it_behaves_like "a row action in place", "Link deleted"
  end

  describe "a task's sessions and comments" do
    let(:task) { create(:task, title: "Write the brief", worked_seconds: 1800) }
    let(:screen) { "/admin/tasks/#{task.id}" }

    before do
      create(:work_session, task_id: task.id, started_at: Time.now - 3600, ended_at: Time.now - 1800)
      create(:task_comment, task_id: task.id, body: "First thought")
    end

    describe "deleting a session" do
      def act = confirm_yes { click_button("Delete session") }

      it_behaves_like "a row action in place", "Session deleted"
    end

    describe "deleting a comment" do
      def act = confirm_yes { click_button("Delete comment") }

      it_behaves_like "a row action in place", "Comment deleted"
    end

    describe "editing a session" do
      before do
        visit screen
        keep_page
        first("summary", text: "Edit").click
        click_button("Save", match: :first)
      end

      it "still posts and loads the page" do
        find(".toast")

        expect(kept_page?).to be(false)
      end
    end
  end

  describe "the upcoming sprints" do
    let(:screen) { "/admin/tasks?filter=upcoming" }

    before { create(:sprint, sprint_date: today + 2) }

    describe "dropping a sprint" do
      def act = confirm_yes { click_button("Drop") }

      it_behaves_like "a row action in place", "Sprint dropped"
    end

    describe "declining the drop" do
      before do
        visit screen
        keep_page
        confirm_no { click_button("Drop") }
      end

      it "asks first and keeps the sprint", :aggregate_failures do
        expect(page).to have_no_css(".toast")
        expect(page).to have_button("Drop")
        expect(kept_page?).to be(true)
      end
    end

    describe "opening a sprint" do
      before do
        visit screen
        keep_page
        click_button("Open sprint")
      end

      it "still posts and loads the page" do
        find(".toast")

        expect(kept_page?).to be(false)
      end
    end
  end
end
