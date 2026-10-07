# frozen_string_literal: true

RSpec.describe "Admin tags", type: :feature do
  let(:repo) { Tags::Slice["repos.tag_queries"] }

  def editor = find(".tag-editor", visible: :visible)

  def open_editor(name) = find(".tag-row", text: "##{name}").find(".tag-pen").click

  before do
    create(:tag, name: "ruby", color: "mk-blue")
    create(:tag, name: "hanami", color: "mk-green")
    sign_in_to_admin
    visit "/admin/tags"
  end

  it "keeps the editor shut until the edit button is clicked" do
    expect(page).to have_no_css(".tag-editor", visible: :visible)
  end

  it "opens the tag's summary from the tag" do
    find(".tag-row .tag-name a", text: "#ruby").click

    expect(page).to have_current_path("/admin/tags/ruby")
  end

  describe "with the editor open" do
    before { open_editor("ruby") }

    it "opens the one tag that was clicked", :aggregate_failures do
      expect(page.all(".tag-editor", visible: :visible).size).to eq(1)
      expect(editor).to have_field("tag[name]", with: "ruby")
    end

    it "renames the tag" do
      editor.fill_in("tag[name]", with: "rails")
      editor.click_on("Save")

      expect(page).to have_css(".tag-name", text: "#rails")
    end

    it "recolours the tag on a swatch click" do
      find(".tag-editor .swatch.orange").click
      page.assert_selector("[data-toast]", text: "Tag recoloured")

      expect(repo.all_in("public").find { it.name == "ruby" }.color).to eq("mk-orange")
    end

    it "shuts again on cancel" do
      editor.find("label", text: "Cancel").click

      expect(page).to have_no_css(".tag-editor", visible: :visible)
    end
  end

  it "filters the list as the query is typed" do
    fill_in("q", with: "han")

    expect(page).to have_css(".tag-name", text: "#hanami").and have_no_css(".tag-name", text: "#ruby")
  end
end
