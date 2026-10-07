# frozen_string_literal: true

RSpec.describe "Admin decision edit notes", type: :feature do
  let(:decision) { create(:decision, title: "Pick a queue", problem: "Jobs pile up") }
  let(:option) { create(:decision_option, decision_id: decision.id, title: "Sidekiq", body: "Runs today") }
  let(:repo) { Decisions::Slice["repos.decision_queries"] }

  def confirm(note)
    dialog.fill_in "What changed and why", with: note
    dialog.click_button "Save"
  end

  def dialog = find("dialog[data-edit-note-dialog][open]")

  def notes
    Decisions::Slice["relations.decision_events"].where(decision_id: decision.id).to_a.filter_map { it[:note] }
  end

  before do
    sign_in_to_admin
    option
    Decisions::Slice["operations.drop_decision"].call(decision.id, { reason: "No need" })
  end

  describe "editing the problem" do
    before { visit "/admin/decisions/#{decision.id}/edit" }

    it "saves a new title without asking" do
      fill_in "Title", with: "Pick a job queue"
      click_button "Save"

      expect(page).to have_css(".toast", text: "Decision saved")
    end

    describe "after the problem changes" do
      before do
        fill_in "Problem", with: "Jobs pile up fast"
        click_button "Save"
      end

      it "asks for the note in a modal and saves nothing yet", :aggregate_failures do
        expect(dialog).to have_field("What changed and why")
        expect(repo.by_id(decision.id).problem).to eq("Jobs pile up")
      end

      it "saves the problem and the note on confirm", :aggregate_failures do
        confirm("Measured it")

        expect(page).to have_css(".toast", text: "Decision saved")
        expect(notes).to eq(["Measured it"])
      end
    end
  end

  describe "editing an option" do
    before do
      visit "/admin/decisions/#{decision.id}"
      within("#decision-option-#{option.id}") do
        find("summary", text: "Edit").click
        fill_in "Option", with: "Sidekiq 8"
        click_button "Save option"
      end
    end

    it "asks for the note in a modal and saves nothing yet", :aggregate_failures do
      expect(dialog).to have_field("What changed and why")
      expect(repo.by_id(decision.id).options.map(&:title)).to eq(["Sidekiq"])
    end

    it "saves the option and the note on confirm", :aggregate_failures do
      confirm("Renamed it")

      expect(page).to have_css(".toast", text: "Option saved")
      expect(notes).to eq(["Renamed it"])
    end
  end
end
