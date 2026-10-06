# frozen_string_literal: true

RSpec.describe "Admin post edit notes", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:post_edit_repo) { Posts::Slice["repos.post_edit_repo"] }
  let(:article) { create(:post, :published, slug: "hello") }

  def card = page.find(".card", text: "Edit notes")

  def edit_path(edit, post_id: article.id) = "/admin/posts/#{post_id}/edits/#{edit.id}"

  def message(key) = i18n.t(key, scope: "ui.components.posts.field_error")

  def notes = post_edit_repo.for_post(article.id).map(&:note)

  def read = get("/admin/posts/#{article.id}/edit")

  def revise(edit, note, **)
    post edit_path(edit, **), _csrf_token: admin_csrf_token, edit: { note: }
  end

  describe "signed out" do
    it "changes nothing" do
      edit = create(:post_edit, post: article, note: "Before")
      post edit_path(edit), edit: { note: "After" }

      expect(notes).to eq(["Before"])
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the card" do
      it "lists a published post's notes newest first" do
        create(:post_edit, post: article, note: "First", created_at: Time.utc(2026, 9, 1))
        create(:post_edit, post: article, note: "Second", created_at: Time.utc(2026, 9, 2))
        read

        expect(card.all(".edit-note-body").map(&:text)).to eq(%w[Second First])
      end

      it "dates each note" do
        edit = create(:post_edit, post: article, created_at: Time.utc(2026, 9, 1, 15))
        read

        expect(card.find("li#post-edit-#{edit.id} time")["datetime"]).to eq(Blog::TimeZone.local(edit.created_at).iso8601)
      end

      it "renders the note as Markdown" do
        create(:post_edit, post: article, note: "Fixed the `numbers`")
        read

        expect(card).to have_css(".edit-note-body code", text: "numbers")
      end

      it "stays in the sidebar while the new note box sits below the body", :aggregate_failures do
        create(:post_edit, post: article)
        read

        expect(page.find(".side-stack").all(".card-label").map(&:text).first).to eq("Edit notes")
        expect(page.find(".editor-main").all(".card-label").map(&:text)).to eq(["What changed and why"])
      end

      it "is absent when the post has no notes" do
        read

        expect(page).to have_no_css(".card-label", exact_text: "Edit notes")
      end

      it "is absent on a draft" do
        draft = create(:post, :draft, slug: "draft")
        get "/admin/posts/#{draft.id}/edit"

        expect(page).to have_no_css(".card-label", exact_text: "Edit notes")
      end

      it "offers no way to delete a note" do
        edit = create(:post_edit, post: article)
        read

        expect([card.has_button?("Delete"), page.has_css?("form[action*='/edits/#{edit.id}/delete']")])
          .to eq([false, false])
      end
    end

    describe "the edit form without JavaScript" do
      let!(:edit) { create(:post_edit, post: article, note: "Before") }

      before { read }

      def form = page.find("form#post-edit-#{edit.id}-form", visible: :all)

      it "posts its own form, outside the post form", :aggregate_failures do
        expect(form["action"]).to eq(edit_path(edit))
        expect(form["method"]).to eq("post")
        expect(form).to have_field("_csrf_token", type: "hidden")
        expect(page).to have_no_css("form[data-post-editor] form")
      end

      it "ties the note box and the save button to that form", :aggregate_failures do
        tied = "[form='#{form['id']}']"

        expect(card).to have_css("[data-markdown-editor] textarea[name='edit[note]']#{tied}", visible: :all)
        expect(card).to have_css("button[type='submit']#{tied}", visible: :all, text: "Save note")
      end

      it "fills the box with the saved note" do
        expect(card.find("textarea[name='edit[note]']", visible: :all).text(:all)).to eq("Before")
      end

      it "keeps the box closed until asked" do
        expect(card.find("details.edit-note-edit")["open"]).to be_nil
      end
    end

    describe "editing a note" do
      let!(:edit) { create(:post_edit, post: article, note: "Before", created_at: Time.utc(2026, 9, 1)) }

      it "saves the new wording, trimmed" do
        revise(edit, "  After  ")

        expect(notes).to eq(["After"])
      end

      it "keeps the note's time" do
        revise(edit, "After")

        expect(post_edit_repo.for_post(article.id).first.created_at).to eq(Time.utc(2026, 9, 1))
      end

      it "comes back to the editor and says so", :aggregate_failures do
        revise(edit, "After")
        expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/posts/#{article.id}/edit"))
        follow_redirect!

        expect(page.find("[data-toast] .toast", visible: :all).text(:all)).to eq("Note saved")
        expect(card.find(".edit-note-body").text).to eq("After")
      end

      it "takes a note of 500 characters" do
        revise(edit, "a" * 500)

        expect(notes.map(&:size)).to eq([500])
      end

      it "leaves the post alone" do
        expect { revise(edit, "After") }.not_to(change { Posts::Slice["repos.post_repo"].by_id(article.id).to_h })
      end
    end

    describe "a blank note" do
      let!(:edit) { create(:post_edit, post: article, note: "Before") }

      before { revise(edit, "   ") }

      it "answers 422 and keeps the old wording" do
        expect([last_response.status, notes]).to eq([422, ["Before"]])
      end

      it "says why beside that note's box", :aggregate_failures do
        expect(page.find("#post-edit-#{edit.id}-note-error").text).to eq(message("note.blank"))
        expect(page.find("#post-edit-#{edit.id}-note")["aria-describedby"]).to eq("post-edit-#{edit.id}-note-error")
      end

      it "opens that note's box" do
        expect(card.find("li#post-edit-#{edit.id} details")["open"]).not_to be_nil
      end
    end

    describe "a note over 500 characters" do
      let!(:edit) { create(:post_edit, post: article, note: "Before") }

      before { revise(edit, "a" * 501) }

      it "says why and keeps what was typed", :aggregate_failures do
        expect(last_response.status).to eq(422)
        expect(page.find("#post-edit-#{edit.id}-note-error").text).to eq(message("edit_note.long"))
        expect(card.find("#post-edit-#{edit.id}-note").text).to eq("a" * 501)
      end

      it "keeps the old wording" do
        expect(notes).to eq(["Before"])
      end
    end

    it "refuses a note with a control character" do
      edit = create(:post_edit, post: article, note: "Before")
      revise(edit, "a\u0007b")

      expect(page.find("#post-edit-#{edit.id}-note-error").text).to eq(message("edit_note.control"))
    end

    it "answers 404 for another post's note", :aggregate_failures do
      other = create(:post, :published, slug: "other")
      edit = create(:post_edit, post: other, note: "Before")
      revise(edit, "After", post_id: article.id)

      expect(last_response.status).to eq(404)
      expect(post_edit_repo.for_post(other.id).map(&:note)).to eq(["Before"])
    end

    it "answers 404 for a note that isn't there" do
      revise(Struct.new(:id).new(999_999), "After")

      expect(last_response.status).to eq(404)
    end
  end
end
