# frozen_string_literal: true

RSpec.describe "Admin photo claims", type: :request do
  let(:photo) { create(:photo) }
  let(:other) { create(:photo) }

  def claims = Media::Slice["relations.photo_claims"]

  def claims_of(owner) = claims.where(owner:).to_a.map { [it[:owner_id], it[:photo_id]] }

  def keys = Media::Slice["relations.photos"].to_a.map { it[:key] }

  def markdown(*photos) = photos.map { "![A photo](/media/#{it.key})" }.join("\n\n")

  def send_to(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def stub_store_delete(*photos) = photos.each { stub_request(:delete, media_store_url(it.key)) }

  before do
    sign_in_to_admin
    connect_media_store
  end

  describe "a post" do
    let(:post_queries) { Posts::Slice["repos.post_queries"] }

    def article = post_queries.all.first

    def save(**fields) = send_to("/admin/posts", intent: "draft", post: { title: "Hello", **fields })

    def update(**fields) = send_to("/admin/posts/#{article.id}", intent: "draft", post: { title: "Hello", **fields })

    it "claims the photos its body points to" do
      save(body: markdown(photo, other))

      expect(claims_of("post")).to contain_exactly([article.id, photo.id], [article.id, other.id])
    end

    it "claims a photo by its absolute URL" do
      save(body: "![A photo](#{Blog::Site.url("/media/#{photo.key}")})")

      expect(claims_of("post")).to eq([[article.id, photo.id]])
    end

    it "claims the photo in its Open Graph image field" do
      save(body: "text only", og_image_url: Blog::Site.url("/media/#{photo.key}"))

      expect(claims_of("post")).to eq([[article.id, photo.id]])
    end

    it "claims the photo a social card write puts in the Open Graph image field" do
      save(body: "text only")
      Posts::Slice["operations.save_post_seo"].call(article.id, og_image_url: Blog::Site.url("/media/#{photo.key}"))

      expect(claims_of("post")).to eq([[article.id, photo.id]])
    end

    it "claims a photo an accepted suggestion puts in its body" do
      save(body: "a cat sat here")
      edit = { original: "a cat", replacement: "#{markdown(photo)} a cat", reason: "show it" }
      Suggestions::Slice["repos.suggestion_mutations"].replace_for_post(article.id, [edit])
      send_to("/admin/posts/#{article.id}/suggestions/accept")

      expect(claims_of("post")).to eq([[article.id, photo.id]])
    end

    describe "edit notes" do
      let(:published) { create(:post, :published, slug: "hello", body: "one") }

      def edit = post_queries.edits_for_post(published.id).first

      def revise(note) = send_to("/admin/posts/#{published.id}/edits/#{edit.id}", edit: { note: })

      def save_published(**fields)
        send_to("/admin/posts/#{published.id}", intent: "save", post: { title: "Hello", slug: "hello", **fields })
      end

      it "claims the photo a new edit note points to" do
        save_published(body: "two", edit_note: markdown(photo))

        expect(claims_of("post")).to eq([[published.id, photo.id]])
      end

      it "keeps the claim when a later save leaves the note alone" do
        save_published(body: "two", edit_note: markdown(photo))
        save_published(body: "two", og_title: "On the card")

        expect(claims_of("post")).to eq([[published.id, photo.id]])
      end

      it "moves the claim to the photo a revised note points to" do
        save_published(body: "two", edit_note: markdown(photo))
        revise(markdown(other))

        expect(claims_of("post")).to eq([[published.id, other.id]])
      end

      it "keeps the photo through the sweep", :aggregate_failures do
        stub_store_delete(photo)
        save_published(body: "two", edit_note: markdown(photo))
        Media::Slice["operations.sweep_photos"].call(at: Time.now + (2 * 24 * 60 * 60))

        expect(keys).to include(photo.key)
        expect(a_request(:delete, media_store_url(photo.key))).not_to have_been_made
      end
    end

    it "claims nothing for a key no photo carries" do
      save(body: "![Gone](/media/#{'f' * 32}.png)")

      expect(claims.count).to eq(0)
    end

    it "drops the claim on a photo taken out of its body", :aggregate_failures do
      save(body: markdown(photo, other))
      update(body: markdown(other))

      expect(claims_of("post")).to eq([[article.id, other.id]])
      expect(keys).to contain_exactly(photo.key, other.key)
    end

    describe "deleted", :commits do
      before do
        stub_store_delete(photo, other)
        save(body: markdown(photo, other))
      end

      def remove = send_to("/admin/posts/#{article.id}/delete")

      it "deletes its photos from the table and the store", :aggregate_failures do
        remove

        expect(keys).to be_empty
        expect(claims.count).to eq(0)
        expect(a_request(:delete, media_store_url(photo.key))).to have_been_made
        expect(a_request(:delete, media_store_url(other.key))).to have_been_made
      end

      it "keeps a photo a journal entry also claims", :aggregate_failures do
        send_to("/admin/journal", entry: { body: markdown(photo) })
        remove

        expect(keys).to eq([photo.key])
        expect(a_request(:delete, media_store_url(photo.key))).not_to have_been_made
      end

      it "leaves a photo it no longer points to for the sweep", :aggregate_failures do
        update(body: markdown(other))
        remove

        expect(keys).to eq([photo.key])
        expect(a_request(:delete, media_store_url(photo.key))).not_to have_been_made
      end

      it "keeps a photo whose store delete fails", :aggregate_failures do
        stub_request(:delete, media_store_url(photo.key)).to_timeout
        remove

        expect(keys).to eq([photo.key])
        expect(claims.count).to eq(0)
      end
    end
  end

  describe "a journal entry" do
    let(:repo) { Record::Slice["repos.journal_entry_queries"] }

    def entry = repo.between(from: Blog::TimeZone.today - 1, to: Blog::TimeZone.today).first

    before { send_to("/admin/journal", entry: { body: markdown(photo, other) }) }

    it "claims the photos its body points to" do
      expect(claims_of("journal_entry")).to contain_exactly([entry.id, photo.id], [entry.id, other.id])
    end

    it "drops the claim on a photo taken out of its body" do
      send_to("/admin/journal/#{entry.id}", entry: { body: markdown(other) })

      expect(claims_of("journal_entry")).to eq([[entry.id, other.id]])
    end

    it "deletes its photos with it", :aggregate_failures, :commits do
      stub_store_delete(photo, other)
      send_to("/admin/journal/#{entry.id}/delete")

      expect(keys).to be_empty
      expect(a_request(:delete, media_store_url(photo.key))).to have_been_made
    end
  end

  describe "a review note" do
    def note = Record::Slice["relations.review_notes"].to_a.first

    def save(body) = send_to("/admin/review/note", day: "2026-09-20", note: { body: })

    before { save(markdown(photo, other)) }

    it "claims the photos its body points to" do
      expect(claims_of("review_note")).to contain_exactly([note[:id], photo.id], [note[:id], other.id])
    end

    it "drops the claim on a photo taken out of its body" do
      save(markdown(other))

      expect(claims_of("review_note")).to eq([[note[:id], other.id]])
    end
  end

  describe "a task" do
    let(:tasks) { Tasks::Slice["relations.tasks"] }

    def task = tasks.to_a.first

    before { send_to("/admin/tasks", filter: "next", task: { title: "Fix the gutter", note: markdown(photo) }) }

    it "claims the photos its note points to" do
      expect(claims_of("task")).to eq([[task[:id], photo.id]])
    end

    it "drops the claim on a photo taken out of its note" do
      send_to("/admin/tasks/#{task[:id]}", filter: "next", task: { title: "Fix the gutter", note: markdown(other) })

      expect(claims_of("task")).to eq([[task[:id], other.id]])
    end

    it "deletes its photos and its comments' photos with it", :aggregate_failures, :commits do
      stub_store_delete(photo, other)
      send_to("/admin/tasks/#{task[:id]}/comments", filter: "next", comment: { body: markdown(other) })
      send_to("/admin/tasks/#{task[:id]}/delete", filter: "next")

      expect(keys).to be_empty
      expect(claims.count).to eq(0)
    end
  end

  describe "a task comment" do
    let(:task) { create(:task) }
    let(:comments) { Tasks::Slice["relations.task_comments"] }

    def comment = comments.to_a.first

    def path = "/admin/tasks/#{task.id}/comments"

    before { send_to(path, filter: "next", comment: { body: markdown(photo, other) }) }

    it "claims the photos its body points to" do
      expect(claims_of("task_comment")).to contain_exactly([comment[:id], photo.id], [comment[:id], other.id])
    end

    it "drops the claim on a photo taken out of its body" do
      send_to("#{path}/#{comment[:id]}", filter: "next", comment: { body: markdown(other) })

      expect(claims_of("task_comment")).to eq([[comment[:id], other.id]])
    end

    it "deletes its photos with it", :aggregate_failures, :commits do
      stub_store_delete(photo, other)
      send_to("#{path}/#{comment[:id]}/delete", filter: "next")

      expect(keys).to be_empty
      expect(a_request(:delete, media_store_url(other.key))).to have_been_made
    end
  end

  describe "a decision comment" do
    let(:decision) { create(:decision) }
    let(:comments) { Decisions::Slice["relations.decision_comments"] }

    def comment = comments.to_a.first

    def path = "/admin/decisions/#{decision.id}/comments"

    before { send_to(path, comment: { body: markdown(photo, other) }) }

    it "claims the photos its body points to" do
      expect(claims_of("decision_comment")).to contain_exactly([comment[:id], photo.id], [comment[:id], other.id])
    end

    it "drops the claim on a photo taken out of its body" do
      send_to("#{path}/#{comment[:id]}", comment: { body: markdown(other) })

      expect(claims_of("decision_comment")).to eq([[comment[:id], other.id]])
    end

    it "deletes its photos with it", :aggregate_failures, :commits do
      stub_store_delete(photo, other)
      send_to("#{path}/#{comment[:id]}/delete")

      expect(keys).to be_empty
      expect(a_request(:delete, media_store_url(other.key))).to have_been_made
    end
  end
end
