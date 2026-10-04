# frozen_string_literal: true

RSpec.describe "Admin review note", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Record::Slice["repos.journal_entry_repo"] }
  let(:sunday) { Date.new(2026, 9, 20) }
  let(:toast) { page.find("[data-toast] .toast", visible: :all).text(:all) }

  def form = notes.find("form#review-note-form[method='post'][action='/admin/review/note']")

  def notes = page.find_by_id("review-notes")

  def review_entries = repo.between(from: Date.new(2026, 9, 1), to: Date.new(2026, 10, 31))

  def save_note(body, **params)
    post "/admin/review/note", _csrf_token: admin_csrf_token, day: sunday.iso8601, note: { body: }, **params
  end

  it "redirects to sign-in when signed out", :aggregate_failures do
    save_note("good week")

    expect(last_response.location).to end_with("/admin/sign-in")
    expect(review_entries).to be_empty
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

    it "writes a journal entry tagged review and dated the week's last day" do
      save_note("good week")

      expect(review_entries.map { [it.body, it.entry_date, it.tags.map(&:name)] })
        .to eq([["good week", sunday, ["review"]]])
    end

    it "returns to the same week with the toast", :aggregate_failures do
      save_note("good week")
      follow_redirect!

      expect(last_request.fullpath).to eq("/admin/review?day=2026-09-20")
      expect(toast).to eq("Review note saved · private")
    end

    it "dates a month's note on the month's last day and returns to the month", :aggregate_failures do
      save_note("good month", period: "month", day: "2026-09-30")

      expect(review_entries.map(&:entry_date)).to eq([Date.new(2026, 9, 30)])
      expect(last_response.location).to end_with("/admin/review?period=month&day=2026-09-30")
    end

    it "dates a note for the week under way on its last day, even when that is still to come" do
      today = Blog::TimeZone.today
      last_day = today + (7 - today.cwday)
      save_note("halfway", day: last_day.iso8601)

      expect(repo.tagged_on("review", last_day).body).to eq("halfway")
    end

    it "shows the saved note in the box and offers to update it", :aggregate_failures do
      save_note("good week")
      get "/admin/review", day: "2026-09-16"

      expect(notes).to have_field("Review note", with: "good week")
      expect(notes).to have_button("Update note")
    end

    it "updates the saved entry in place of adding a second" do
      save_note("good week")
      save_note("great week")

      expect(review_entries.map(&:body)).to eq(["great week"])
    end

    it "keeps the tags already on the entry when it updates it" do
      save_note("good week")
      repo.replace_tags(review_entries.first.id, %w[health review])
      save_note("great week")

      expect(review_entries.first.tags.map(&:name)).to eq(%w[health review])
    end

    it "leaves another entry on the same day alone" do
      create(:journal_entry, entry_date: sunday, body: "walked the dog")
      save_note("good week")

      expect(review_entries.map(&:body)).to contain_exactly("walked the dog", "good week")
    end

    it "lists the note in the journal" do
      save_note("good week")
      get "/admin/journal", to: sunday.iso8601

      expect(page).to have_css(".journal-entry-body", text: "good week")
    end

    it "lists the note in the activity feed" do
      save_note("good week")
      get "/admin/activity", to: sunday.iso8601

      expect(page).to have_css(".activity-event-name", text: "good week")
    end

    describe "a blank note" do
      before { save_note(" \n ") }

      it "answers 422 and saves nothing" do
        expect([last_response.status, review_entries]).to eq([422, []])
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

      expect([last_response.status, review_entries.map(&:body)]).to eq([422, ["good week"]])
    end

    it "refuses a day it cannot read" do
      save_note("good week", day: "2026-13-40")

      expect([last_response.status, review_entries]).to eq([400, []])
    end
  end
end
