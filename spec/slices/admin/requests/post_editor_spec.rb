# frozen_string_literal: true

RSpec.describe "Admin post editor", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:i18n) { Admin::Slice["i18n"] }
  let(:toast) { page.find("[data-toast] .toast", visible: :all).text(:all) }

  def card
    {
      og_title: "On the card",
      og_image_url: "https://example.com/card.png",
      canonical_url: "https://elsewhere.example/hello",
    }
  end

  def field_error = page.find(".field-error").text

  def note_box = "[data-markdown-editor] textarea[name='post[edit_note]']"

  def post_queries = Posts::Slice["repos.post_queries"]

  def save(path = "/admin/posts", intent: "draft", **fields)
    post path, _csrf_token: admin_csrf_token, intent:, post: fields
  end

  def save_from(view, path = "/admin/posts", **fields)
    post path, _csrf_token: admin_csrf_token, intent: "draft", view:, post: fields
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "a new post" do
      before { get "/admin/posts/new" }

      it "titles the page New post" do
        expect(page).to have_title("New post | Admin | #{Hanami.app.settings.owner_name}")
      end

      it "shows no edit note box" do
        expect(page).to have_no_css(note_box)
      end

      it "links back to the posts list" do
        expect(page).to have_link("All posts", href: "/admin/posts")
      end

      it "posts the form to create a post" do
        expect(page).to have_css("form[method='post'][action='/admin/posts'][data-post-editor]")
      end

      it "carries the CSRF token" do
        expect(page).to have_field("_csrf_token", type: "hidden")
      end

      it "renders the title as the heading input" do
        expect(page).to have_field("Title", class: "editor-title", with: "", placeholder: "Post title")
      end

      it "heads the page with the title, its sub line, the summary and the actions", :aggregate_failures do
        head = page.find("header.page-head")

        expect(head).to have_css(".editor-head .page-head-sub", text: "/writing/")
        expect(head).to have_field("Summary", class: "editor-summary")
        expect(head).to have_css(".page-head-actions button", text: "Save draft")
      end

      it "renders an empty summary field beside the title" do
        placeholder = i18n.t("ui.components.posts.editor.summary_placeholder")

        expect(page).to have_field("Summary", class: "editor-summary", with: "", placeholder:)
      end

      it "renders the social card fields", :aggregate_failures do
        expect(page).to have_field("Card title", with: "", placeholder: "Post title")
        expect(page).to have_field("Card image", with: "", type: "url")
        expect(page).to have_field("Canonical link", with: "", type: "url")
      end

      it "offers Save draft" do
        expect(page).to have_button("Save draft", class: "bt")
      end

      it "offers no delete before the post exists" do
        expect(page).to have_no_button("Delete")
      end

      it "offers Publish, with Schedule hidden", :aggregate_failures do
        expect(page).to have_css("button.bt.pri[value='publish'] [data-editor-now]:not([hidden])", text: "Publish")
        expect(page).to have_css("button.bt.pri [data-editor-later][hidden]", text: "Schedule", visible: :all)
      end

      it "switches the pane from a segmented control above it" do
        expect(page.all(".edit > .edit-pane-head .seg-option").map(&:text)).to eq(%w[Write Preview])
      end

      it "labels the switch for screen readers" do
        expect(page).to have_css(".edit .seg[role='radiogroup'][aria-label='Editor view']")
      end

      it "starts on Write" do
        expect(page).to have_css(".seg input[name='view'][value='write'][checked]", visible: :all)
      end

      it "renders the toolbar buttons" do
        expect(page.all(".toolbar button[type='button']").map(&:text)).to eq(%w[H2 B I code quote])
      end

      it "gives each toolbar button its snippet" do
        snippets = page.all(".toolbar button").map { it["data-snippet"] }

        expect(snippets).to eq(["\n\n## ", "**bold**", "*italic*", "\n\n```ruby\n\n```", "\n\n> "])
      end

      it "renders the body textarea" do
        expect(page).to have_field("Body", type: "textarea", class: "edit-body")
      end

      it "shows the write pane and hides the preview without the script", :aggregate_failures do
        expect(page).to have_css(".edit-pane[data-editor-view='write']:not([hidden])")
        expect(page).to have_css(".edit-pane[data-editor-view='preview'][hidden]", visible: :all)
      end

      it "gives the script the preview endpoint" do
        expect(page).to have_css(".edit-pane .preview[data-editor-preview='/admin/posts/preview']", visible: :all)
      end

      it "renders an empty body in the preview" do
        expect(page).to have_css(".preview .post-body", exact_text: "", visible: :all)
      end

      it "renders the publishing card", :aggregate_failures do
        expect(page).to have_css(".card-label", text: "Publishing")
        expect(page).to have_field("Slug", with: "")
        expect(page).to have_field("Tags", placeholder: "ruby, patterns")
        expect(page).to have_field("Publish time (Chicago)", type: "datetime-local")
      end

      it "says publishing goes live now" do
        expect(page).to have_css(".hint:not([hidden])", text: i18n.t("ui.components.posts.publishing.hint_now"))
      end

      it "shows the path, word count and read time in the sub-line" do
        expect(page).to have_css(".page-head-sub", exact_text: "/writing/ · 0 words · ~1 min read")
      end

      it "gives the script the word templates" do
        words = page.find("[data-editor-words]")

        expect([words["data-one"], words["data-other"]]).to eq(i18n.t("ui.components.posts.editor.words").values)
      end

      it "gives the script the read time template" do
        template = page.find("[data-editor-read-time]")["data-editor-read-time"]

        expect(template).to eq(i18n.t("ui.components.posts.editor.read_time"))
      end

      it "gives the script the path prefix" do
        expect(page).to have_css("[data-editor-path='/writing/']")
      end

      it "keeps saying posts is where you are" do
        expect(page).to have_css(".pill-nav-link[aria-current='page']", text: "Publish")
      end
    end

    describe "editing a scheduled post" do
      let(:scheduled) do
        create(:post, :scheduled, title: "Hello", slug: "hello", tags: %w[ruby hanami], body: "one two",
                                  published_at: Time.utc(2030, 9, 7, 15, 30))
      end

      before { get "/admin/posts/#{scheduled.id}/edit" }

      it "titles the page with the post's title" do
        expect(page).to have_title("Hello | Admin | #{Hanami.app.settings.owner_name}")
      end

      it "fills the form from the post", :aggregate_failures do
        expect(page).to have_field("Title", with: "Hello")
        expect(page).to have_field("Slug", with: "hello")
        expect(page).to have_field("Tags", with: "hanami, ruby")
        expect(page).to have_field("Body", with: "one two")
      end

      it "renders the post in the preview", :aggregate_failures do
        preview = page.find("[data-post-editor] .preview", visible: :all)

        expect(preview).to have_css("h2.preview-title", exact_text: "Hello", visible: :all)
        expect(preview).to have_css(".post-meta time", exact_text: "Sep 7, 2030", visible: :all)
        expect(preview.all(".post-meta .post-tag", visible: :all).map(&:text)).to eq(%w[hanami ruby])
        expect(preview).to have_css(".post-body p", exact_text: "one two", visible: :all)
      end

      it "shows the publish time on the Chicago clock" do
        expect(page).to have_field("Publish time (Chicago)", with: "2030-09-07T10:30")
      end

      it "posts the form to the post" do
        expect(page).to have_css("form[method='post'][action='/admin/posts/#{scheduled.id}']")
      end

      it "reads Schedule for a future publish time" do
        expect(page).to have_css("button.bt.pri [data-editor-later]:not([hidden])", text: "Schedule")
      end

      it "draws no edit note dialog" do
        expect(page).to have_no_css("[data-edit-note-dialog]", visible: :all)
      end

      it "says publishing will schedule it" do
        expect(page).to have_css(".hint:not([hidden])", text: i18n.t("ui.components.posts.publishing.hint_later"))
      end

      it "shows no edit note box" do
        expect(page).to have_no_css(note_box)
      end
    end

    describe "editing a published post" do
      let(:published) { create(:post, :published, title: "Hello", slug: "hello", tags: %w[ruby hanami]) }

      before { get "/admin/posts/#{published.id}/edit" }

      it "fills the form from the post", :aggregate_failures do
        expect(page).to have_field("Title", with: "Hello")
        expect(page).to have_field("Tags", with: "hanami, ruby")
        expect(page).to have_field("Publish time (Chicago)", with: Blog::TimeZone.input_value(published.published_at))
      end

      it "makes the slug read-only" do
        expect(page).to have_field("Slug", with: "hello", readonly: true)
      end

      it "makes the publish time read-only" do
        expect(page).to have_field("Publish time (Chicago)", readonly: true)
      end

      it "offers Save" do
        expect(page).to have_button("Save", class: %w[bt pri], exact: true)
      end

      it "offers neither Save draft nor Publish" do
        expect(page).to have_no_button("Save draft").and have_no_button("Publish", visible: :all)
      end

      it "shows no publishing hint" do
        expect(page).to have_no_css(".hint[data-editor-now], .hint[data-editor-later]", visible: :all)
      end

      it "asks what changed and why in the shared Markdown editor", :aggregate_failures do
        expect(page).to have_css(".card-label", exact_text: "What changed and why")
        expect(page).to have_css(".card #{note_box}#post-edit_note")
        expect(page).to have_field("What changed and why", with: "")
      end

      it "puts the note box below the body" do
        expect(page).to have_css(".editor-main > [data-markdown-editor]:has(#post-body) + .card #{note_box}")
      end

      it "keeps the note box out of the sidebar" do
        expect(page).to have_no_css(".side-stack #{note_box}")
      end

      it "draws a hidden dialog for the note inside the post form", :aggregate_failures do
        dialog = page.find("form[data-post-editor] dialog[data-edit-note-dialog][hidden]", visible: :all)

        expect(dialog).to have_button("Cancel", type: "button", visible: :all)
        expect(dialog).to have_button("Save", type: "button", visible: :all)
      end

      it "keeps the note box out of the dialog until a script moves it" do
        expect(page).to have_no_css("dialog #{note_box}", visible: :all)
      end
    end

    describe "editing a post" do
      it "counts the words and read time in the sub-line" do
        post = create(:post, slug: "hello", body: (["word"] * 700).join(" "))
        get "/admin/posts/#{post.id}/edit"

        expect(page).to have_css(".page-head-sub", exact_text: "/writing/hello · 700 words · ~3 min read")
      end

      it "shows no edit note box on a draft" do
        post = create(:post, :draft)
        get "/admin/posts/#{post.id}/edit"

        expect(page).to have_no_css(note_box)
      end

      it "leaves the publish time empty on a draft that has none" do
        post = create(:post, :draft, published_at: nil)
        get "/admin/posts/#{post.id}/edit"

        expect(page).to have_field("Publish time (Chicago)", with: "")
      end

      it "uses the slugified title as the slug placeholder" do
        post = create(:post, title: "Héllo, Wörld!")
        get "/admin/posts/#{post.id}/edit"

        expect(page).to have_field("Slug", placeholder: "hello-world")
      end

      it "fills the summary the post carries" do
        post = create(:post, summary: "What it is about", body: "The opening paragraph")
        get "/admin/posts/#{post.id}/edit"

        expect(page).to have_field("Summary", with: "What it is about")
      end

      it "leaves the summary field empty when the post carries none" do
        post = create(:post, summary: "", body: "The opening paragraph")
        get "/admin/posts/#{post.id}/edit"

        expect(page).to have_field("Summary", with: "")
      end

      it "fills the social card fields the post carries", :aggregate_failures do
        get "/admin/posts/#{create(:post, **card).id}/edit"

        expect(page).to have_field("Card title", with: "On the card")
        expect(page).to have_field("Card image", with: "https://example.com/card.png")
        expect(page).to have_field("Canonical link", with: "https://elsewhere.example/hello")
      end

      it "reads Publish for a past publish time" do
        post = create(:post, :draft, published_at: Time.now - 60)
        get "/admin/posts/#{post.id}/edit"

        expect(page).to have_css("button.bt.pri [data-editor-now]:not([hidden])", text: "Publish")
      end

      it "returns 404 for a post that doesn't exist" do
        get "/admin/posts/0/edit"

        expect(last_response).to be_not_found
      end
    end

    describe "the details drawer" do
      def drawer = page.find("form[data-post-editor] dialog#post-details.wide[role='dialog'][aria-modal='true']")

      def fields = %w[slug tags publish_at og_title og_image_url canonical_url syndication_body webmentions_enabled]

      def opener
        "button[type='button'][data-dialog-open='post-details'][command='show-modal'][commandfor='post-details']"
      end

      it "opens from the Details button, with or without scripts" do
        get "/admin/posts/new"

        expect(page).to have_css(".page-head-actions #{opener}", text: "Details")
      end

      it "holds the publishing, card, syndication and webmention fields inside the editor form" do
        get "/admin/posts/new"

        expect(fields.select { drawer.has_field?(name: "post[#{it}]") }).to eq(fields)
      end

      it "leaves checking to the server, so a bad field in the shut drawer cannot block a save silently" do
        get "/admin/posts/new"

        expect(page).to have_css("form[data-post-editor][novalidate]")
      end

      it "stays shut on a fresh editor" do
        get "/admin/posts/new"

        expect(page).to have_no_css("dialog#post-details[open]")
      end

      it "opens when one of its fields fails" do
        create(:post, slug: "hello")
        save(title: "Hello")

        expect(page).to have_css("dialog#post-details[open]")
      end

      it "stays shut when only the title fails" do
        save(title: "")

        expect(page).to have_no_css("dialog#post-details[open]")
      end
    end

    describe "the analytics link" do
      it "shows on a published post" do
        article = create(:post, :published)
        get "/admin/posts/#{article.id}/edit"

        expect(page).to have_css(".page-head-actions a[href='/admin/posts/#{article.id}/analytics']", text: "Analytics")
      end

      it "stays off a draft" do
        article = create(:post, :draft)
        get "/admin/posts/#{article.id}/edit"

        expect(page).to have_no_css(".page-head-actions a[href$='/analytics']")
      end
    end

    describe "deleting a post" do
      let(:article) { create(:post, :published, slug: "hello") }

      def confirmation = delete_form["data-confirm"]

      def delete_form = page.find("form#post-delete", visible: :all)

      def edit = get "/admin/posts/#{article.id}/edit"

      def remove(id = article.id) = post "/admin/posts/#{id}/delete", _csrf_token: admin_csrf_token

      it "offers Delete post in the foot of the Details drawer" do
        edit

        expect(page).to have_css(
          "dialog#post-details .dialog-foot button.warn[form='post-delete']", text: "Delete post",
        )
      end

      it "draws a hidden trash icon before the Delete label" do
        edit

        expect(page).to have_css(
          "button.bt.warn[type='submit'][form='post-delete'] > i.fa-trash-can[aria-hidden='true']:first-child",
          visible: :all,
        )
      end

      it "posts the delete form with the CSRF token", :aggregate_failures do
        edit

        expect(delete_form["action"]).to eq("/admin/posts/#{article.id}/delete")
        expect(delete_form).to have_field("_csrf_token", type: "hidden")
      end

      it "asks to confirm without a count when nothing was received" do
        edit

        expect(confirmation).to eq(i18n.t("ui.components.posts.delete_form.confirm"))
      end

      [1, 2].each do |count|
        it "names #{count} webmention in the confirmation" do
          count.times { create(:webmention, post: article) }
          edit

          expect(confirmation).to eq(i18n.t("ui.components.posts.delete_form.confirm_webmentions", count:))
        end
      end

      it "removes the post" do
        remove

        expect(post_queries.by_id(article.id)).to be_nil
      end

      it "returns to the list with the toast", :aggregate_failures do
        remove
        follow_redirect!

        expect(last_request.path).to eq("/admin/posts")
        expect(toast).to eq("Post deleted")
      end

      it "takes the post's edit notes with it" do
        create(:post_edit, post: article)
        remove

        expect(post_queries.edits_for_post(article.id)).to be_empty
      end

      it "takes the post's webmentions with it" do
        create(:webmention, :approved, post: article)
        remove

        expect(Social::Slice["repos.webmention_queries"].received_count(article.id)).to eq(0)
      end

      it "leaves a social post in place, detached", :aggregate_failures do
        social_post_queries = Social::Slice["repos.social_post_queries"]
        social = create(:social_post, :posted, post_id: article.id)
        remove

        expect(social_post_queries.by_id(social.id)).not_to be_nil
        expect(social_post_queries.any_for_post?(article.id)).to be(false)
      end

      it "drops the post from the public site" do
        remove
        get "/writing/hello"

        expect(last_response).to be_not_found
      end

      it "rejects a delete without a CSRF token", :aggregate_failures do
        post "/admin/posts/#{article.id}/delete"

        expect(last_response.status).to eq(403)
        expect(post_queries.by_id(article.id)).not_to be_nil
      end
    end

    describe "webmentions" do
      let(:webmention_mutations) { Social::Slice["repos.webmention_mutations"] }

      def toggle = page.find_field("Accept webmentions", type: "checkbox")

      it "heads the card and hints at what the toggle does", :aggregate_failures do
        get "/admin/posts/new"

        expect(page).to have_css(".card-label", text: "Webmentions")
        expect(page).to have_css(".hint", text: i18n.t("ui.components.posts.webmentions.hint"))
      end

      it "starts a new post on when new posts are enabled by default" do
        webmention_mutations.update_settings(enable_on_new_posts: true)
        get "/admin/posts/new"

        expect(toggle).to be_checked
      end

      it "starts a new post off when new posts are disabled by default" do
        webmention_mutations.update_settings(enable_on_new_posts: false)
        get "/admin/posts/new"

        expect(toggle).not_to be_checked
      end

      it "reads the flag off the post being edited" do
        post = create(:post, webmentions_enabled: false)
        get "/admin/posts/#{post.id}/edit"

        expect(toggle).not_to be_checked
      end

      it "keeps the toggle as typed after invalid input" do
        save(title: "", webmentions_enabled: "0")

        expect(toggle).not_to be_checked
      end

      it "counts the mentions the post received, whatever their status" do
        post = create(:post)
        create(:webmention, post: post)
        create(:webmention, :spam, post: post)
        get "/admin/posts/#{post.id}/edit"

        expect(page).to have_css(".hint", text: "2 received so far")
      end

      it "counts an ignored mention as received" do
        post = create(:post)
        create(:webmention, :approved, post: post)
        create(:webmention, :ignored, post: post)
        get "/admin/posts/#{post.id}/edit"

        expect(page).to have_css(".hint", text: "2 received so far")
      end

      it "counts one mention in the singular" do
        post = create(:post)
        create(:webmention, post: post)
        get "/admin/posts/#{post.id}/edit"

        expect(page).to have_css(".hint", text: "1 received so far")
      end

      it "says nothing about a post without mentions" do
        post = create(:post)
        get "/admin/posts/#{post.id}/edit"

        expect(page).to have_no_css(".hint", text: "received so far")
      end

      it "turns the flag off" do
        post = create(:post, webmentions_enabled: true)
        save("/admin/posts/#{post.id}", title: "Hello", webmentions_enabled: "0")

        expect(post_queries.by_id(post.id)).to have_attributes(webmentions_enabled: false)
      end

      it "turns the flag on" do
        post = create(:post, webmentions_enabled: false)
        save("/admin/posts/#{post.id}", title: "Hello", webmentions_enabled: "1")

        expect(post_queries.by_id(post.id)).to have_attributes(webmentions_enabled: true)
      end

      it "turns the flag off on a published post" do
        post = create(:post, :published, slug: "hello", webmentions_enabled: true)
        save("/admin/posts/#{post.id}", intent: "save", title: "Hello", slug: "hello", body: post.body,
                                        webmentions_enabled: "0")

        expect(post_queries.by_id(post.id)).to have_attributes(status: "published", webmentions_enabled: false)
      end

      it "sets the flag on a new post" do
        webmention_mutations.update_settings(enable_on_new_posts: true)
        save(title: "Hello", webmentions_enabled: "0")

        expect(post_queries.all.last).to have_attributes(webmentions_enabled: false)
      end

      it "leaves the flag to the default when the form doesn't send it" do
        webmention_mutations.update_settings(enable_on_new_posts: false)
        save(title: "Hello")

        expect(post_queries.all.last).to have_attributes(webmentions_enabled: false)
      end
    end

    describe "syndication" do
      let(:card) do
        { syndication_enabled: "1", syndication_body: "In my own words",
          syndication_targets: %w[mastodon bluesky] }
      end

      def ada
        create(:person, key: "ada", mastodon_handle: "@ada@ruby.social", bluesky_handle: "ada.bsky.social",
                        bluesky_did: "did:plc:ada")
      end

      def bluesky_only = { syndication_targets: %w[bluesky] }

      def delivered
        stub_bluesky
        Social::Jobs::SyndicatePost.drain
        Social::Jobs::DeliverSocialPost.new.perform(queued.first.id, social_account("bluesky").id)

        bluesky_writes.first.dig("record", "text")
      end

      def queued
        Social::Jobs::SyndicatePost.drain
        Social::Slice["repos.social_post_queries"].queued
      end

      def text_field = page.find_field("Cross-post text")

      def toggle = page.find_field("Queue a cross-post when this goes live", type: "checkbox")

      before { connect_social_networks }

      it "heads the card and hints at what it does", :aggregate_failures do
        get "/admin/posts/new"

        expect(page).to have_css(".card-label", text: "Syndication")
        expect(page).to have_css(".hint", text: i18n.t("ui.components.posts.syndication.hint"))
      end

      it "starts a new post on, with every connected network picked", :aggregate_failures do
        get "/admin/posts/new"

        expect(toggle).to be_checked
        expect(page.all("[data-social-target]").map { it["value"] }).to eq(%w[mastodon bluesky])
        expect(page.all("[data-social-target]")).to all(be_checked)
      end

      it "names the pills for the post form" do
        get "/admin/posts/new"

        expect(page.all("[data-social-target]").map { it["name"] }).to all(eq("post[syndication_targets][]"))
      end

      it "disables a network with no credentials" do
        connect_social_networks(bluesky: {})
        get "/admin/posts/new"

        expect(page.find("[data-social-target='bluesky']", visible: :all)).to be_disabled
      end

      it "counts the text for each network as it goes out" do
        post = create(:post, title: "Hello", slug: "hello")
        get "/admin/posts/#{post.id}/edit"

        expect(page.all("[data-social-count-text]").map(&:text)).to eq(["Mastodon 30/500", "Bluesky 55/300"])
      end

      it "marks the text over the Bluesky limit once its link to the site is tagged" do
        body = "#{'a' * 262} https://aaronmallen.me/writing/hello"
        post = create(:post, syndication_body: body, syndication_targets: %w[bluesky])
        get "/admin/posts/#{post.id}/edit"

        expect(page).to have_css(".compose-count.over", text: "Bluesky")
      end

      it "counts a mention in the text as each network gets it" do
        create(:person, key: "ada", mastodon_handle: "@ada@ruby.social", bluesky_handle: "ada.bsky.social",
                        bluesky_did: "did:plc:ada")
        post = create(:post, syndication_body: "hi @{ada}")
        get "/admin/posts/#{post.id}/edit"

        expect(page.all("[data-social-count-text]").map(&:text)).to eq(["Mastodon 7/500", "Bluesky 19/300"])
      end

      it "starts the text with the title and the post's URL" do
        post = create(:post, title: "Hello", slug: "hello")
        get "/admin/posts/#{post.id}/edit"

        expect(text_field.value).to eq("Hello\n\nhttps://aaronmallen.me/writing/hello")
      end

      it "keeps the text saved with the post" do
        post = create(:post, syndication_body: "In my own words")
        get "/admin/posts/#{post.id}/edit"

        expect(text_field.value).to eq("In my own words")
      end

      it "reads the card off the post being edited", :aggregate_failures do
        post = create(:post, syndication_enabled: true, syndication_targets: %w[bluesky])
        get "/admin/posts/#{post.id}/edit"

        expect(toggle).to be_checked
        expect(page.find("[data-social-target='bluesky']", visible: :all)).to be_checked
        expect(page.find("[data-social-target='mastodon']", visible: :all)).not_to be_checked
      end

      it "keeps what was typed after invalid input", :aggregate_failures do
        save(title: "", **card)

        expect(text_field.value).to eq("In my own words")
        expect(toggle).to be_checked
      end

      it "saves the card with the post" do
        save(title: "Hello", **card)

        expect(post_queries.all.last)
          .to have_attributes(syndication_enabled: true, syndication_body: "In my own words",
                              syndication_targets: %w[mastodon bluesky])
      end

      it "sends an empty network list ahead of the pills" do
        get "/admin/posts/new"

        expect(page).to have_css("input[type='hidden'][name='post[syndication_targets][]'][value='']", visible: :all)
      end

      it "clears the networks when every pill is off" do
        post = create(:post, :draft, slug: "hello", syndication_targets: %w[mastodon bluesky])
        save("/admin/posts/#{post.id}", title: "Hello", slug: "hello", **card, syndication_targets: [""])

        expect(post_queries.by_id(post.id)).to have_attributes(syndication_targets: [])
      end

      it "queues nothing when every pill is off", :aggregate_failures, :commits do
        post = create(:post, :draft, slug: "hello", syndication_targets: %w[mastodon bluesky])
        save("/admin/posts/#{post.id}", intent: "publish", title: "Hello", slug: "hello", **card,
                                        syndication_targets: [""])

        expect(post_queries.by_id(post.id)).to have_attributes(status: "published")
        expect(queued).to be_empty
      end

      it "queues the cross-post when the post is published", :commits do
        save(intent: "publish", title: "Hello", **card)

        expect(queued).to contain_exactly(
          have_attributes(post_id: post_queries.all.last.id, targets: %w[mastodon bluesky],
                          parts: [have_attributes(body: "In my own words")]),
        )
      end

      it "queues nothing for a scheduled post until it goes live", :commits do
        save(intent: "publish", title: "Hello", publish_at: "2030-09-07T10:30", **card)

        expect(queued).to be_empty
      end

      it "queues nothing for a draft", :commits do
        save(title: "Hello", **card)

        expect(queued).to be_empty
      end

      it "queues nothing with the toggle off", :commits do
        save(intent: "publish", title: "Hello", **card, syndication_enabled: "0")

        expect(queued).to be_empty
      end

      it "queues nothing twice when a published post is saved again", :commits do
        save(intent: "publish", title: "Hello", **card)
        save("/admin/posts/#{post_queries.all.last.id}", intent: "save", title: "Hello", slug: "hello", **card)

        expect(queued.size).to eq(1)
      end

      it "refuses to publish text over a picked network's limit", :aggregate_failures do
        save(intent: "publish", title: "Hello", **card, syndication_body: "a" * 301)

        expect(last_response.status).to eq(422)
        expect(field_error).to eq(i18n.t("ui.components.posts.field_error.syndication_body.too_long"))
        expect(post_queries.all).to be_empty
      end

      it "refuses an announcement that fits Bluesky only before its link to the site is tagged" do
        typed = "#{'a' * 262} https://aaronmallen.me/writing/hello"
        save(intent: "publish", title: "Hello", **card, **bluesky_only, syndication_body: typed)

        expect(field_error).to eq(i18n.t("ui.components.posts.field_error.syndication_body.too_long"))
      end

      it "refuses a title and link that fit Bluesky only before the link is tagged" do
        save(intent: "publish", title: "a" * 262, slug: "hello", **card, **bluesky_only, syndication_body: "")

        expect(field_error)
          .to eq(i18n.t("ui.components.posts.field_error.syndication_body.announcement_too_long"))
      end

      it "publishes a title and link that still fit Bluesky once the link is tagged" do
        save(intent: "publish", title: "a" * 250, slug: "hello", **card, **bluesky_only, syndication_body: "")

        expect(post_queries.all.last.status).to eq("published")
      end

      it "names the title and link when the blank box is what goes over", :aggregate_failures do
        save(intent: "publish", title: "a" * 301, slug: "hello", **card, syndication_body: "")

        expect(last_response.status).to eq(422)
        expect(field_error)
          .to eq(i18n.t("ui.components.posts.field_error.syndication_body.announcement_too_long"))
        expect(post_queries.all).to be_empty
      end

      it "refuses an announcement that fits Bluesky only before its mention expands", :aggregate_failures do
        ada
        save(intent: "publish", title: "Hello", **card, **bluesky_only, syndication_body: "#{'a' * 290} @{ada}")

        expect(last_response.status).to eq(422)
        expect(field_error).to eq(i18n.t("ui.components.posts.field_error.syndication_body.too_long"))
        expect(post_queries.all).to be_empty
      end

      it "publishes and delivers an announcement that fits once its mention expands", :aggregate_failures, :commits do
        ada
        save(intent: "publish", title: "Hello", **card, **bluesky_only, syndication_body: "#{'a' * 280} @{ada}")

        expect(post_queries.all.last.status).to eq("published")
        expect(delivered).to eq("#{'a' * 280} @ada.bsky.social")
      end

      it "refuses a mention that names nobody in the directory", :aggregate_failures do
        save(title: "Hello", **card, syndication_body: "hi @{grace}")

        expect(last_response.status).to eq(422)
        expect(field_error).to eq(i18n.t("ui.components.posts.field_error.syndication_body.unknown_mention"))
      end
    end

    describe "saving a draft" do
      it "creates a draft" do
        save(title: "Hello", body: "one two", tags: "Ruby, hanami, ruby")

        expect(post_queries.all).to contain_exactly(
          have_attributes(title: "Hello", slug: "hello", status: "draft", body: "one two"),
        )
      end

      it "returns to the editor and shows the toast", :aggregate_failures do
        save(title: "Hello")
        follow_redirect!

        expect(last_request.path).to eq("/admin/posts/#{post_queries.all.last.id}/edit")
        expect(toast).to eq("Draft saved")
      end

      it "updates a draft" do
        draft = create(:post, :draft, slug: "hello")
        save("/admin/posts/#{draft.id}", title: "Changed", slug: "changed", body: "new")

        expect(post_queries.by_id(draft.id)).to have_attributes(title: "Changed", slug: "changed", body: "new")
      end

      it "creates a draft for an intent it doesn't know" do
        save(intent: "launch", title: "Hello")

        expect(post_queries.all).to contain_exactly(have_attributes(status: "draft", published_at: nil))
      end

      it "keeps a draft a draft for an intent it doesn't know" do
        draft = create(:post, :draft, slug: "hello")
        save("/admin/posts/#{draft.id}", intent: %w[publish], title: "Hello", slug: "hello")

        expect(post_queries.by_id(draft.id)).to have_attributes(status: "draft", published_at: nil)
      end

      it "saves the summary, trimmed" do
        save(title: "Hello", summary: "  What it is about  ", body: "one two")

        expect(post_queries.all.last.written_summary).to eq("What it is about")
      end

      it "saves a blank summary as nothing written" do
        save(title: "Hello", summary: "   ", body: "one two")

        expect(post_queries.all.last.written_summary).to be_nil
      end

      it "saves the social card fields" do
        save(title: "Hello", body: "one two", **card)

        expect(post_queries.all.last).to have_attributes(**card)
      end

      it "refuses a card image that is not a link" do
        save(title: "Hello", body: "one two", og_image_url: "card.png")

        expect(field_error).to eq(i18n.t("ui.components.posts.field_error.og_image_url.format"))
      end

      it "keeps the publish time on a draft" do
        save(title: "Hello", publish_at: "2030-09-07T10:30")

        expect(post_queries.all.last).to have_attributes(status: "draft", published_at: Time.utc(2030, 9, 7, 15, 30))
      end

      it "changes the body of a draft with no note", :aggregate_failures do
        draft = create(:post, :draft, slug: "hello", body: "one")
        save("/admin/posts/#{draft.id}", title: "Hello", slug: "hello", body: "two")

        expect(post_queries.by_id(draft.id).body).to eq("two")
        expect(post_queries.edits_for_post(draft.id)).to be_empty
      end

      it "changes the body of a scheduled post with no note", :aggregate_failures do
        scheduled = create(:post, :scheduled, slug: "hello", body: "one")
        publish_at = Blog::TimeZone.input_value(scheduled.published_at)
        save("/admin/posts/#{scheduled.id}", intent: "publish", title: "Hello", slug: "hello", body: "two", publish_at:)

        expect(post_queries.by_id(scheduled.id)).to have_attributes(status: "scheduled", body: "two")
        expect(post_queries.edits_for_post(scheduled.id)).to be_empty
      end

      it "keeps a scheduled time in the hour the clock repeats when daylight saving ends" do
        repeated_hour = Time.utc(2030, 11, 3, 7, 30)
        scheduled = create(:post, :scheduled, slug: "hello", published_at: repeated_hour)
        publish_at = Blog::TimeZone.input_value(scheduled.published_at)
        save("/admin/posts/#{scheduled.id}", intent: "publish", title: "Goodbye", slug: "hello", publish_at:)

        expect(post_queries.by_id(scheduled.id)).to have_attributes(title: "Goodbye", published_at: repeated_hour)
      end

      it "turns a scheduled post back into a draft" do
        scheduled = create(:post, :scheduled, slug: "hello")
        save("/admin/posts/#{scheduled.id}", title: "Hello", slug: "hello")

        expect(post_queries.by_id(scheduled.id)).to have_attributes(status: "draft")
      end

      it "returns 404 for invalid input to a post that doesn't exist" do
        save("/admin/posts/0", title: "")

        expect(last_response).to be_not_found
      end
    end

    describe "publishing" do
      it "publishes now without a publish time" do
        save(intent: "publish", title: "Hello")

        expect(post_queries.all.last).to have_attributes(status: "published", published_at: be_within(5).of(Time.now))
      end

      it "shows the published toast" do
        save(intent: "publish", title: "Hello")
        follow_redirect!

        expect(toast).to eq("Published")
      end

      it "publishes now with a past publish time, keeping that time" do
        save(intent: "publish", title: "Hello", publish_at: "2026-09-07T10:30")

        expect(post_queries.all.last)
          .to have_attributes(status: "published", published_at: Time.utc(2026, 9, 7, 15, 30))
      end

      it "publishes a draft" do
        draft = create(:post, :draft)
        save("/admin/posts/#{draft.id}", intent: "publish", title: "Hello")

        expect(post_queries.by_id(draft.id)).to have_attributes(status: "published")
      end

      it "schedules a post with a future publish time" do
        save(intent: "publish", title: "Hello", publish_at: "2030-09-07T10:30")

        expect(post_queries.all.last)
          .to have_attributes(status: "scheduled", published_at: Time.utc(2030, 9, 7, 15, 30))
      end

      it "shows the scheduled toast with the Chicago time" do
        save(intent: "publish", title: "Hello", publish_at: "2030-09-07T10:30")
        follow_redirect!

        expect(toast).to eq("Scheduled for Sep 7, 2030, 10:30")
      end
    end

    describe "saving a published post" do
      let(:published) do
        create(:post, :published, title: "Hello", slug: "hello", body: "one", published_at: Time.utc(2026, 9, 1))
      end

      def note_error(code) = i18n.t(code, scope: "ui.components.posts.field_error.edit_note")

      def save_published(**fields)
        save("/admin/posts/#{published.id}", intent: "save", title: "Hello", slug: "hello", body: "one", **fields)
      end

      it "saves it and keeps it published at its time" do
        save_published(title: "Changed", publish_at: "")

        expect(post_queries.by_id(published.id))
          .to have_attributes(title: "Changed", status: "published", published_at: Time.utc(2026, 9, 1))
      end

      it "shows the saved toast" do
        save_published(title: "Changed")
        follow_redirect!

        expect(toast).to eq("Saved")
      end

      it "rejects a slug change and changes nothing", :aggregate_failures do
        save_published(title: "Changed", slug: "goodbye")

        expect(field_error).to eq(i18n.t("ui.components.posts.field_error.slug.locked"))
        expect(post_queries.by_id(published.id)).to have_attributes(title: "Hello", slug: "hello")
      end

      it "refuses a body change with no note and changes nothing", :aggregate_failures do
        save_published(body: "two", edit_note: "  ")

        expect([last_response.status, field_error]).to eq([422, note_error("blank")])
        expect(post_queries.by_id(published.id).body).to eq("one")
        expect(post_queries.edits_for_post(published.id)).to be_empty
      end

      it "shows the note error under the note box" do
        save_published(body: "two")

        expect(page).to have_css("#post-edit_note[aria-invalid='true'][aria-describedby='post-edit_note-error']")
      end

      it "shows the note error below the body", :aggregate_failures do
        save_published(body: "two")

        expect(page).to have_css(".editor-main #post-edit_note-error", text: note_error("blank"))
        expect(page).to have_no_css(".side-stack #post-edit_note-error")
      end

      it "keeps the rest of the form after a missing note", :aggregate_failures do
        save_published(title: "Changed", body: "two", tags: "ruby")

        expect(page).to have_field("Title", with: "Changed")
        expect(page).to have_field("Body", with: "two")
        expect(page).to have_field("Tags", with: "ruby")
      end

      it "saves a body change with its note", :aggregate_failures do
        save_published(body: "two", edit_note: "fixed the `numbers`")

        expect(post_queries.by_id(published.id)).to have_attributes(body: "two", status: "published")
        expect(post_queries.edits_for_post(published.id).map(&:note)).to eq(["fixed the `numbers`"])
      end

      it "saves a change to the tags and social card with no note", :aggregate_failures do
        save_published(tags: "ruby", **card)

        expect(post_queries.by_id(published.id)).to have_attributes(**card)
        expect(post_queries.by_id(published.id).tags.map(&:name)).to eq(%w[ruby])
        expect(post_queries.edits_for_post(published.id)).to be_empty
      end

      it "keeps no note when the body stays the same" do
        save_published(title: "Changed", edit_note: "Nothing to say")

        expect(post_queries.edits_for_post(published.id)).to be_empty
      end

      it "reads a body sent back with Windows line endings as the same body" do
        published = create(:post, :published, slug: "lines", body: "one\ntwo")
        save("/admin/posts/#{published.id}", intent: "save", title: "Lines", slug: "lines", body: "one\r\ntwo")

        expect(last_response).to be_redirect
      end

      it "refuses a note over 500 characters", :aggregate_failures do
        save_published(body: "two", edit_note: "a" * 501)

        expect(field_error).to eq(note_error("long"))
        expect(post_queries.by_id(published.id).body).to eq("one")
      end

      it "takes a note of 500 characters" do
        save_published(body: "two", edit_note: "a" * 500)

        expect(post_queries.edits_for_post(published.id).map { it.note.size }).to eq([500])
      end

      it "refuses a note with a control character" do
        save_published(body: "two", edit_note: "a\u0007b")

        expect(field_error).to eq(note_error("control"))
      end

      it "keeps the note as typed after a failed save" do
        save_published(title: "  ", body: "two", edit_note: "Fixed a typo")

        expect(page.find(".editor-main")).to have_field("What changed and why", with: "Fixed a typo")
      end
    end

    describe "invalid input" do
      def message(key) = i18n.t(key, scope: "ui.components.posts.field_error")

      it "answers 422 and saves nothing for a blank title" do
        save(title: "  ", body: "kept")

        expect([last_response.status, post_queries.all]).to eq([422, []])
      end

      it "shows the title error next to the title", :aggregate_failures do
        save(title: "  ")

        expect(page).to have_css("#post-title-error.field-error", exact_text: message("title.blank"))
        expect(page).to have_css("#post-title[aria-invalid='true'][aria-describedby='post-title-error']")
      end

      it "keeps what was typed" do
        save(title: "  ", body: "kept")

        expect(page).to have_field("Body", with: "kept")
      end

      it "comes back on the tab the save came from", :aggregate_failures do
        save_from("preview", title: "  ")

        expect(page).to have_css(".edit-pane[data-editor-view='preview']:not([hidden])")
        expect(page).to have_css(".seg input[name='view'][value='preview'][checked]", visible: :all)
      end

      it "comes back on Write for a view it doesn't know" do
        save_from("gallery", title: "  ")

        expect(page).to have_css(".edit-pane[data-editor-view='write']:not([hidden])")
      end

      it "comes back on the tab an update came from" do
        draft = create(:post, title: "Draft", slug: "draft")
        save_from("preview", "/admin/posts/#{draft.id}", title: "  ")

        expect(page).to have_css(".edit-pane[data-editor-view='preview']:not([hidden])")
      end

      it "shows an error for a slug another post has and saves nothing", :aggregate_failures do
        create(:post, slug: "hello")
        save(title: "Hello")

        expect([last_response.status, field_error]).to eq([422, message("slug.taken")])
        expect(post_queries.all.size).to eq(1)
      end

      it "shows an error for a duplicate slug on update and changes nothing", :aggregate_failures do
        create(:post, slug: "hello")
        draft = create(:post, title: "Draft", slug: "draft")
        save("/admin/posts/#{draft.id}", title: "Changed", slug: "hello")

        expect(field_error).to eq(message("slug.taken"))
        expect(post_queries.by_id(draft.id)).to have_attributes(title: "Draft", slug: "draft")
      end

      it "keeps the edit form's action on an update error" do
        draft = create(:post)
        save("/admin/posts/#{draft.id}", title: "")

        expect(page).to have_css("form[action='/admin/posts/#{draft.id}']")
      end

      it "reserves the tags slug" do
        save(title: "Tags")

        expect(field_error).to eq(message("slug.reserved"))
      end

      it "rejects a slug in the wrong format" do
        save(title: "Hello", slug: "Hello World")

        expect(field_error).to eq(message("slug.format"))
      end

      %w[-hello hello- hello--world héllo hello/world].each do |slug|
        it "rejects the slug #{slug.inspect}" do
          save(title: "Hello", slug:)

          expect(field_error).to eq(message("slug.format"))
        end
      end

      it "rejects a tag with a slash" do
        save(title: "Hello", tags: "ruby, a/b")

        expect(field_error).to eq(message("tags.format"))
      end

      it "rejects a Chicago time the clocks skip and saves nothing" do
        save(intent: "publish", title: "Hello", publish_at: "2027-03-14T02:30")

        expect([field_error, post_queries.all]).to eq([message("publish_at.skipped"), []])
      end

      it "rejects a publish time it can't read" do
        save(title: "Hello", publish_at: "2026-02-30T10:00")

        expect(field_error).to eq(message("publish_at.format"))
      end

      it "rejects a save without a CSRF token" do
        post "/admin/posts", intent: "draft", post: { title: "Hello" }

        expect([last_response.status, post_queries.all]).to eq([403, []])
      end
    end
  end

  describe "signed out" do
    %w[/admin/posts/new /admin/posts/1/edit].each do |path|
      it "redirects #{path} to sign-in" do
        get path

        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
      end
    end

    it "deletes nothing", :aggregate_failures do
      article = create(:post)
      post "/admin/posts/#{article.id}/delete"

      expect(last_response).not_to be_successful
      expect(post_queries.by_id(article.id)).not_to be_nil
    end
  end
end
