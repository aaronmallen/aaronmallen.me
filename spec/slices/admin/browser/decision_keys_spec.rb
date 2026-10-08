# frozen_string_literal: true

RSpec.describe "Admin decision keys", type: :feature do
  let(:decision) { create(:decision, title: "Pick a queue") }
  let(:key) { "##{decision.id}" }

  def copied = translate("ui.components.record_key.copied.decision", key:)

  def translate(key, **) = Admin::Slice["i18n"].t(key, **)

  before { sign_in_to_admin }

  describe "clicking the key in the list" do
    before do
      decision
      visit "/admin/decisions"
      watch_clipboard
      find(".decision-row", text: "Pick a queue").find(".record-key").click
    end

    it "copies the key", :aggregate_failures do
      expect(page).to have_css(".toast", text: copied)
      expect(page.evaluate_script("window.copiedKeys")).to eq([key])
    end
  end

  describe "clicking the key on the decision page" do
    before do
      visit "/admin/decisions/#{decision.id}"
      watch_clipboard
      find(".read-meta .record-key").click
    end

    it "copies the key", :aggregate_failures do
      expect(page).to have_css(".toast", text: copied)
      expect(page.evaluate_script("window.copiedKeys")).to eq([key])
    end
  end
end
