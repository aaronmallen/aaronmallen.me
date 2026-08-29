# frozen_string_literal: true

RSpec.describe "Admin post editor", type: :feature do
  let(:body) { find_field("Body") }
  let(:post_repo) { Posts::Slice["repos.post_repo"] }

  def click_tool(label) = find("[role='toolbar'] button[aria-label='#{label}']").click

  def show_view(name) = find(".edit .seg-option", text: name).click

  def translate(key, **) = Admin::Slice["i18n"].t(key, **)

  before do
    sign_in_to_admin
    visit "/admin/posts/new"
  end

  describe "the syndication card" do
    let(:bluesky) { Social::Slice["networks.all"].fetch("bluesky") }
    let(:link) { "Read https://aaronmallen.me/writing/hello and tell me" }
    let(:mastodon) { Social::Slice["networks.all"].fetch("mastodon") }

    def counts = all("[data-social-count-text]").map(&:text)

    def write(text) = fill_in("Cross-post text", with: text)

    before do
      connect_social_networks
      visit "/admin/posts/new"
    end

    it "counts as you type" do
      write "hello"

      expect(counts).to eq(["Mastodon 5/500", "Bluesky 5/300"])
    end

    it "counts a link the way Mastodon does" do
      write link

      expect(counts.first).to eq("Mastodon #{mastodon.count(link)}/500")
    end

    it "counts emoji the way Bluesky does" do
      write "👍🏽 👨‍👩‍👧 done"

      expect(counts.last).to eq("Bluesky #{bluesky.count('👍🏽 👨‍👩‍👧 done')}/300")
    end

    it "mutes a network that is off" do
      find(".compose-target", text: "Bluesky").click

      expect(page).to have_css(".compose-count.off", text: "Bluesky")
    end

    it "turns text over a network's limit pink" do
      write "a" * 301

      expect(page).to have_css(".compose-count.over", text: "Bluesky")
    end

    it "leaves a network under its limit green" do
      write "a" * 301

      expect(page).to have_no_css(".compose-count.over", text: "Mastodon")
    end

    describe "the preview of what goes out" do
      def field = "Cross-post text"

      def writing = "https://aaronmallen.me/writing"

      it "previews the title and the URL as you type the title" do
        fill_in "Title", with: "A fresh title"

        expect(page).to have_field(field, placeholder: "A fresh title\n\n#{writing}/a-fresh-title")
      end

      it "previews the URL the slug field carries" do
        fill_in "Title", with: "A fresh title"
        fill_in "Slug", with: "chosen"

        expect(page).to have_field(field, placeholder: "A fresh title\n\n#{writing}/chosen")
      end

      it "hints instead while the title is blank" do
        expect(find_field(field)[:placeholder]).to eq(translate("ui.components.posts.syndication.placeholder"))
      end

      it "saves no post to preview one", :aggregate_failures do
        fill_in "Title", with: "A fresh title"

        expect(page).to have_field(field, placeholder: /a-fresh-title/)
        expect(post_repo.all).to be_empty
      end
    end

    describe "counting what goes out" do
      def announcement = "A fresh title\n\nhttps://aaronmallen.me/writing/a-fresh-title"

      it "counts the title and the URL while the box is blank", :aggregate_failures do
        fill_in "Title", with: "A fresh title"

        expect(page).to have_css(".compose-count", text: "Mastodon #{mastodon.count(announcement)}/500")
        expect(page).to have_css(".compose-count", text: "Bluesky #{bluesky.count(announcement)}/300")
      end

      it "counts nothing while the title is blank" do
        expect(counts).to eq(["Mastodon 0/500", "Bluesky 0/300"])
      end

      it "counts the text you type over the title and the URL" do
        fill_in "Title", with: "A fresh title"
        find(".compose-count", text: "Bluesky #{bluesky.count(announcement)}/300")

        write "hello"

        expect(counts).to eq(["Mastodon 5/500", "Bluesky 5/300"])
      end

      it "turns a title over a network's limit pink" do
        fill_in "Title", with: "a" * 301

        expect(page).to have_css(".compose-count.over", text: "Bluesky")
      end
    end
  end

  {
    "Heading" => "\n\n## ",
    "Bold" => "**bold**",
    "Italic" => "*italic*",
    "Code block" => "\n\n```ruby\n\n```",
    "Quote" => "\n\n> ",
  }.each do |label, snippet|
    it "inserts the #{label} snippet" do
      click_tool label

      expect(body.value).to eq(snippet)
    end
  end

  it "labels the summary field where you can see it" do
    expect(page).to have_css("label[for='post-summary']", exact_text: "SUMMARY")
  end

  it "inserts a snippet at the cursor" do
    fill_in "Body", with: "hello world"
    execute_script("document.getElementById('post-body').setSelectionRange(6, 6)")
    click_tool "Bold"

    expect(body.value).to eq("hello **bold**world")
  end

  it "replaces the selected text with the snippet" do
    fill_in "Body", with: "hello world"
    execute_script("document.getElementById('post-body').setSelectionRange(6, 11)")
    click_tool "Italic"

    expect(body.value).to eq("hello *italic*")
  end

  it "counts the words a snippet adds" do
    click_tool "Bold"

    expect(page).to have_css("[data-editor-words]", exact_text: "1 word")
  end

  it "counts words as you type" do
    fill_in "Body", with: "one two three"

    expect(page).to have_css("[data-editor-words]", exact_text: "3 words")
  end

  it "does not count markdown marks as words" do
    fill_in "Body", with: "## one --- two"

    expect(page).to have_css("[data-editor-words]", exact_text: "2 words")
  end

  it "updates the read time as you type" do
    fill_in "Body", with: (["word"] * 700).join(" ")

    expect(page).to have_css("[data-editor-read-time]", exact_text: "~3 min read")
  end

  describe "the Write and Preview tabs" do
    let(:draft) { "# One\n\n  two  \n\nthree" }

    def save_draft
      click_button "Save draft"
      page.assert_selector(".toast", text: "Draft saved")
    end

    it "starts on Write", :aggregate_failures do
      expect(page).to have_field("Body")
      expect(page).to have_no_css(".preview")
    end

    it "shows the preview and hides the textarea on Preview", :aggregate_failures do
      show_view "Preview"

      expect(page).to have_css(".preview")
      expect(page).to have_no_field("Body")
    end

    it "keeps the textarea in the form on Preview" do
      show_view "Preview"

      expect(page).to have_field("Body", visible: :all)
    end

    it "takes the toolbar away on Preview" do
      show_view "Preview"

      expect(page).to have_no_css("[role='toolbar']")
    end

    it "brings the toolbar back on Write" do
      show_view "Preview"
      show_view "Write"

      expect(page).to have_css("[role='toolbar']")
    end

    it "keeps every character of an unsaved body across a round trip" do
      fill_in "Body", with: draft
      show_view "Preview"
      show_view "Write"

      expect(body.value).to eq(draft)
    end

    it "saves the body submitted from Preview" do
      fill_in "Title", with: "Hello"
      fill_in "Body", with: "two words  "
      show_view "Preview"
      save_draft

      expect(post_repo.all.last.body).to eq("two words  ")
    end

    it "switches with the arrow keys" do
      show_view "Write"
      page.driver.browser.keyboard.type(:right)

      expect(page).to have_css(".preview")
    end
  end

  describe "deleting a post" do
    let(:article) { create(:post, :draft, title: "Drop me") }

    before { visit "/admin/posts/#{article.id}/edit" }

    it "asks with the confirmation text" do
      message = dismiss_confirm { click_button "Delete" }

      expect(message).to eq(translate("ui.components.posts.delete_form.confirm"))
    end

    it "names the webmentions it will destroy" do
      create(:webmention, post: article)
      visit "/admin/posts/#{article.id}/edit"
      message = dismiss_confirm { click_button "Delete" }

      expect(message).to eq(translate("ui.components.posts.delete_form.confirm_webmentions", count: 1))
    end

    it "keeps the post when I don't confirm", :aggregate_failures do
      dismiss_confirm { click_button "Delete" }

      expect(page).to have_no_css(".toast")
      expect(page).to have_field("Title", with: "Drop me")
    end

    it "lands on the list with the toast once I confirm", :aggregate_failures do
      accept_confirm { click_button "Delete" }
      page.assert_selector(".toast", text: "Post deleted")

      expect(page).to have_current_path("/admin/posts")
      expect(page).to have_no_css(".li-title", text: "Drop me")
    end
  end
end
