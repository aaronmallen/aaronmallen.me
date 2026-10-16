# frozen_string_literal: true

RSpec.describe "Admin menu tag suggestions", type: :request do
  let(:thread) { create(:message) }

  def suggested
    list = Capybara.string(last_response.body).find("[data-menu-suggest]", visible: :all)

    JSON.parse(list["data-menu-suggest"])
  end

  before do
    sign_in_to_admin
    create(:tag, :private, name: "home", color: "mk-blue")
    create(:tag, name: "ruby")
    Mail::Slice["repos.message_tag_mutations"].add(thread.id, "receipts")
  end

  it "suggests every private tag in a mail menu, mail-only ones too, with their colors" do
    get "/admin/mail/#{thread.id}/menu"

    expect(suggested).to match([{ "name" => "home", "color" => "blue" }, { "name" => "receipts", "color" => String }])
  end

  {
    "a task menu" => -> { "/admin/tasks/#{create(:task).id}/menu" },
    "a task bulk menu" => -> { "/admin/tasks/bulk/menu?#{URI.encode_www_form("ids[]": [create(:task).id])}" },
    "a journal menu" => -> { "/admin/journal/#{create(:journal_entry).id}/menu" },
    "a decision menu" => -> { "/admin/decisions/#{create(:decision).id}/menu" },
  }.each do |name, url|
    it "leaves mail-only tags out of #{name}" do
      get instance_exec(&url)

      expect(suggested.map { it["name"] }).to eq(["home"])
    end
  end

  it "suggests public tags in a post menu" do
    get "/admin/posts/#{create(:post).id}/menu"

    expect(suggested.map { it["name"] }).to eq(["ruby"])
  end
end
