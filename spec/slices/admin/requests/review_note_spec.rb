# frozen_string_literal: true

RSpec.describe "Admin review note", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Record::Slice["repos.journal_entry_repo"] }
  let(:sunday) { Date.new(2026, 9, 20) }
  let(:toast) { page.find("[data-toast] .toast", visible: :all).text(:all) }

  def form = notes.find("form#review-note-form[method='post'][action='/admin/review/note']")

  def note(period = "week", starts_on = Date.new(2026, 9, 14)) = notes_repo.note(period, starts_on)&.body

  def notes = page.find_by_id("review-notes")

  def notes_repo = Record::Slice["repos.review_note_repo"]

  def review_entries = repo.between(from: Date.new(2026, 9, 1), to: Date.new(2026, 10, 31))

  def save_note(body, **params)
    post "/admin/review/note", _csrf_token: admin_csrf_token, day: sunday.iso8601, note: { body: }, **params
  end

  def stored_notes = Record::Slice["relations.review_notes"].to_a

  def today = Blog::TimeZone.today

  it "redirects to sign-in when signed out", :aggregate_failures do
    save_note("good week")

    expect(last_response.location).to end_with("/admin/sign-in")
    expect(stored_notes).to be_empty
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the box" do
      before { get "/admin/review", day: "2026-09-16" }

      it "starts empty" do
        expect(form).to have_field("Review note", with: "")
      end

      it "names the week's last day" do
        expect(form).to have_field("day", type: :hidden, with: "2026-09-20")
      end

      it "posts as a plain form with its token" do
        expect(form).to have_field("_csrf_token", type: :hidden)
      end

      it "saves through a submit button" do
        expect(form).to have_button("Save note")
      end
    end

    it "names the month's last day in a month's box" do
      get "/admin/review", period: "month", day: "2026-09-16"

      fields = form.all("input[type='hidden']", visible: :hidden).to_h { [it[:name], it[:value]] }

      expect(fields.slice("period", "day")).to eq("period" => "month", "day" => "2026-09-30")
    end

    it "keeps the note for the week and writes no journal entry", :aggregate_failures do
      save_note("good week")

      expect(note).to eq("good week")
      expect(review_entries).to be_empty
    end

    it "returns to the same week with the toast", :aggregate_failures do
      save_note("good week")
      follow_redirect!

      expect(last_request.fullpath).to eq("/admin/review?day=2026-09-20")
      expect(toast).to eq("Review note saved · private")
    end

    it "keeps a month's note for the month and returns to the month", :aggregate_failures do
      save_note("good month", period: "month", day: "2026-09-30")

      expect(note("month", Date.new(2026, 9, 1))).to eq("good month")
      expect(last_response.location).to end_with("/admin/review?period=month&day=2026-09-30")
    end

    it "shows the saved note in the box and offers to update it", :aggregate_failures do
      save_note("good week")
      get "/admin/review", day: "2026-09-16"

      expect(notes).to have_field("Review note", with: "good week")
      expect(notes).to have_button("Update note")
    end

    it "updates the saved note in place of adding a second" do
      save_note("good week")
      save_note("great week")

      expect(stored_notes.map { it[:body] }).to eq(["great week"])
    end

    it "leaves an entry on the same day alone" do
      create(:journal_entry, entry_date: sunday, body: "walked the dog")
      save_note("good week")

      expect(review_entries.map(&:body)).to eq(["walked the dog"])
    end

    describe "a month that ends on a Sunday" do
      def note_box(**params)
        get "/admin/review", day: "2026-05-31", **params
        notes.find_field("Review note").value
      end

      def save_month(body) = save_note(body, period: "month", day: "2026-05-31")

      def save_week(body) = save_note(body, day: "2026-05-31")

      it "keeps the month's note when the week's last day saves" do
        save_month("good month")
        save_week("good week")
        save_week("great week")

        expect(stored_notes.map { it[:body] }).to contain_exactly("good month", "great week")
      end

      it "keeps the week's note when the month saves" do
        save_week("good week")
        save_month("good month")
        save_month("great month")

        expect(stored_notes.map { it[:body] }).to contain_exactly("good week", "great month")
      end

      it "shows the week only its own note" do
        save_month("good month")
        save_week("good week")

        expect(note_box).to eq("good week")
      end

      it "shows the month only its own note" do
        save_week("good week")
        save_month("good month")

        expect(note_box(period: "month")).to eq("good month")
      end

      it "starts the month empty when only the week has a note" do
        save_week("good week")

        expect(note_box(period: "month")).to eq("")
      end
    end

    describe "an entry I wrote and tagged review on the week's last day" do
      let!(:mine) { create(:journal_entry, entry_date: sunday, body: "my own review", tags: %w[review]) }

      it "stays out of the box" do
        get "/admin/review", day: sunday.iso8601

        expect(notes).to have_field("Review note", with: "")
      end

      it "stays as I wrote it when the form saves", :aggregate_failures do
        save_note("good week")
        save_note("great week")

        expect(review_entries.map { [it.id, it.body] }).to eq([[mine.id, "my own review"]])
        expect(note).to eq("great week")
      end
    end

    it "keeps the note out of the journal" do
      save_note("good week")
      get "/admin/journal", to: sunday.iso8601

      expect(page).to have_no_css(".journal-entry-body", text: "good week")
    end

    it "keeps the note out of the activity feed" do
      save_note("good week")
      get "/admin/activity", to: sunday.iso8601

      expect(page).to have_no_css(".activity-event-name", text: "good week")
    end

    describe "a week whose only writing is its note" do
      before { save_note("one two three four") }

      it "shows no entries and no words on the screen" do
        get "/admin/review", day: sunday.iso8601

        expect(page.find_by_id("review-journal")).to have_css(".review-note",
                                                              exact_text: "0 entries · 0 words · no streak")
      end

      it "reads no entries and no words through read_review" do
        journal = mcp_answer("read_review", day: sunday.iso8601).fetch("journal")

        expect(journal.slice("entries", "words")).to eq("entries" => [], "words" => 0)
      end
    end

    describe "a note for the week under way" do
      def api_token = API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

      def attention = Activity::Slice["repos.attention_queries"].stalled.select { it.kind == "journal" }

      def calendar_marks
        headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
        get "/api/v1/calendar", { from: (last_day - 6).iso8601, to: last_day.iso8601 }, headers
        JSON.parse(last_response.body).fetch("days").map { it.fetch("journal") }
      end

      def last_day = today + (7 - today.cwday)

      it "keeps the note for the week" do
        save_note("halfway", day: last_day.iso8601)

        expect(note("week", last_day - 6)).to eq("halfway")
      end

      it "leaves no journal entry dated after today" do
        save_note("halfway", day: last_day.iso8601)

        expect(repo.between(from: today + 1, to: last_day + 1)).to be_empty
      end

      it "leaves the calendar with no journal mark" do
        save_note("halfway", day: last_day.iso8601)

        expect(calendar_marks).to all(be(false))
      end

      it "leaves the journal attention row as it was" do
        create(:journal_entry, entry_date: today - 5)
        before = attention.map { [it.record_id, it.days] }
        save_note("halfway", day: last_day.iso8601)

        expect([before, attention.map { [it.record_id, it.days] }]).to eq([[[nil, 5]], [[nil, 5]]])
      end
    end

    describe "a blank note" do
      before { save_note(" \n ") }

      it "answers 422 and saves nothing" do
        expect([last_response.status, stored_notes, review_entries]).to eq([422, [], []])
      end

      it "says why beside the box" do
        message = Admin::Slice["i18n"].t("ui.components.journal.field_error.body.blank")

        expect(notes).to have_css("#review-note-body-error.field-error", exact_text: message)
      end

      it "marks the box as invalid" do
        expect(notes).to have_css("#review-note-body[aria-invalid='true'][aria-describedby='review-note-body-error']")
      end

      it "redraws the same week" do
        expect(page).to have_css(".page-head-sub", text: "Sep 14 → Sep 20, 2026")
      end
    end

    it "leaves a saved note as it was when the new one is blank" do
      save_note("good week")
      save_note("  ")

      expect([last_response.status, note]).to eq([422, "good week"])
    end

    it "refuses a day it cannot read" do
      save_note("good week", day: "2026-13-40")

      expect([last_response.status, stored_notes]).to eq([400, []])
    end
  end
end
