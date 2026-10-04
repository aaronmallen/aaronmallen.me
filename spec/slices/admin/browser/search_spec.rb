# frozen_string_literal: true

RSpec.describe "Admin search screen", type: :feature do
  before do
    create(:task, title: "Track the zeppelin")
    create(:message, subject: "Zeppelin sighting")
    sign_in_to_admin
    visit "/admin/search?q=zeppelin"
  end

  describe "choosing a kind" do
    before { select("Messages", from: "kind") }

    it "submits the filter with the query" do
      expect(page).to have_current_path("/admin/search?q=zeppelin&kind=message")
    end

    it "lists only that kind", :aggregate_failures do
      expect(page).to have_css(".li-title", text: "Zeppelin sighting")
      expect(page).to have_no_css(".li-title", text: "Track the zeppelin")
    end

    describe "reloading" do
      before do
        page.assert_current_path("/admin/search?q=zeppelin&kind=message")
        refresh
      end

      it "keeps the kind and the query", :aggregate_failures do
        expect(page).to have_select("kind", selected: "Messages")
        expect(page).to have_field("q", with: "zeppelin")
        expect(page).to have_no_css(".li-title", text: "Track the zeppelin")
      end
    end
  end

  describe "opening a result" do
    before { click_link("Track the zeppelin") }

    it "goes to its record" do
      expect(page).to have_current_path(%r{\A/admin/tasks/\d+\z})
    end
  end
end
