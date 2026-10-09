# frozen_string_literal: true

RSpec.describe "Admin message labels", type: :feature do
  let(:message) { create(:message, :read, subject: "Invoice") }
  let(:dialog) { find("dialog#label-message-#{message.id}") }
  let(:repo) { Contact::Slice["repos.message_queries"] }
  let(:bad) { Admin::Slice["i18n"].t("ui.components.message_label.bad") }

  def tags = repo.by_id(message.id).tags.map(&:name)

  before do
    create(:tag, :private, name: "billing")
    create(:tag, :private, name: "urgent")
    Contact::Slice["repos.message_tag_mutations"].add(message.id, "billing")
    sign_in_to_admin
    visit "/admin/messages?status=read&open=#{message.id}"
    find(".msg-pane").click_button "Label"
  end

  it "finds a tag as the owner types" do
    dialog.find("input[name='name']").set("urg")

    expect(dialog.all(".label-choice .tag").map(&:text)).to eq(%w[#urgent])
  end

  describe "checking, unchecking and creating" do
    before do
      dialog.find(".label-choice", text: "#billing").click
      dialog.find(".label-choice", text: "#urgent").click
      dialog.find("input[name='name']").set("lead")
      dialog.click_button "Create “#lead”"
    end

    it "counts what is checked" do
      expect(dialog).to have_text("2 selected")
    end

    it "saves the checked tags", :aggregate_failures do
      dialog.click_button "Save"

      expect(page).to have_css(".toast", text: "Labels saved")
      expect(page.all(".msg-letter-tags .tag").map(&:text)).to eq(%w[#lead #urgent])
      expect(tags).to eq(%w[lead urgent])
    end
  end

  it "refuses a bad name", :aggregate_failures do
    dialog.find("input[name='name']").set("two words")

    expect(dialog).to have_text(bad)
    expect(dialog).to have_button("Create “#two words”", disabled: true)
  end
end
