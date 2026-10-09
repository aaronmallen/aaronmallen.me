# frozen_string_literal: true

RSpec.describe "Admin message labels", type: :request do
  let(:repo) { Contact::Slice["repos.message_queries"] }
  let(:tagging) { Contact::Slice["repos.message_tag_mutations"] }
  let(:message) { create(:message, :read, subject: "Invoice") }

  def label(**params) = post("/admin/messages/#{message.id}/label", { _csrf_token: admin_csrf_token, **params })

  def page = Capybara.string(last_response.body)

  def tags = repo.by_id(message.id).tags.map(&:name)

  def toast = page.find("[data-toast] .toast", visible: :all).text(:all)

  before { sign_in_to_admin }

  describe "the reading pane" do
    before do
      create(:tag, :private, name: "billing")
      create(:tag, :private, name: "urgent")
      create(:tag, name: "ruby")
      tagging.add(message.id, "billing")
      get "/admin/messages", status: "read", open: message.id
    end

    let(:dialog) { page.find("dialog#label-message-#{message.id}", visible: :all) }

    it "shows the message's tags under the subject" do
      expect(page.all(".msg-letter-tags .tag").map(&:text)).to eq(%w[#billing])
    end

    it "lists every private tag and checks the message's own", :aggregate_failures do
      boxes = dialog.all("input[name='tags[]']", visible: :all)

      expect(boxes.map(&:value)).to eq(%w[billing urgent])
      expect(boxes.map { it[:checked] }).to eq([true, false])
    end

    it "posts to the message with the list that was open", :aggregate_failures do
      form = dialog.find("form", visible: :all)

      expect(form[:action]).to eq("/admin/messages/#{message.id}/label")
      expect(form).to have_css("input[name='filter'][value='read']", visible: :all)
    end

    it "counts the checked tags" do
      expect(dialog.find(".label-count", visible: :all).text(:all)).to eq("1 selected")
    end
  end

  describe "a list row" do
    it "shows the message's tags" do
      tagging.add(message.id, "billing")
      get "/admin/messages", status: "read"

      expect(page.all("#message-#{message.id} .msg-item-tags .tag").map(&:text)).to eq(%w[#billing])
    end
  end

  describe "saving" do
    it "sets the tags to the ticked ones and a new name", :aggregate_failures do
      tagging.add(message.id, "billing")
      label(tags: %w[urgent], name: " Follow-Up ")
      follow_redirect!

      expect([tags, toast]).to eq([%w[follow-up urgent], "Labels saved"])
    end

    it "returns to the open message in the list it came from" do
      label(name: "lead", filter: "read")

      expect(last_response.location).to eq("/admin/messages?status=read&open=#{message.id}#read-#{message.id}")
    end

    it "keeps new tags private" do
      label(name: "lead")

      expect(Tags::Slice["repos.tag_queries"].all_in("private").map(&:name)).to eq(%w[lead])
    end

    it "clears the tags when none are ticked", :aggregate_failures do
      tagging.add(message.id, "billing")
      label(name: "")
      follow_redirect!

      expect([tags, toast]).to eq([[], "Labels cleared"])
    end

    it "refuses a bad name and keeps the tags", :aggregate_failures do
      tagging.add(message.id, "billing")
      label(tags: %w[billing], name: "two words")
      follow_redirect!

      expect([tags, toast]).to eq([%w[billing], Admin::Slice["i18n"].t("messages_page.toasts.labels_invalid")])
    end

    it "answers 404 for a message that is gone" do
      post "/admin/messages/0/label", { _csrf_token: admin_csrf_token, name: "lead" }

      expect(last_response.status).to eq(404)
    end
  end
end
