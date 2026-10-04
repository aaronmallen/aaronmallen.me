# frozen_string_literal: true

RSpec.describe "Decisions" do
  let(:decision) { create(:decision) }
  let(:comment) { create(:decision_comment, decision_id: decision.id, body: "Leaning on Sidekiq") }
  let(:photo) { create(:photo) }
  let(:other) { create(:photo) }

  def call(name, *) = Decisions::Slice["operations.#{name}"].call(*)

  def claimed = claims.where(owner: "decision_comment").pluck(:owner_id, :photo_id)

  def claims = Media::Slice["relations.photo_claims"]

  def comments = Decisions::Slice["relations.decision_comments"]

  def markdown(*photos) = photos.map { "![A photo](/media/#{it.key})" }.join("\n\n")

  describe "adding a comment" do
    it "keeps the Markdown body on the decision" do
      added = call(:add_decision_comment, decision.id, { body: "  Leaning on **Sidekiq**\r\nfor now " }).value!

      expect(added).to have_attributes(decision_id: decision.id, body: "Leaning on **Sidekiq**\nfor now")
    end

    it "refuses a blank body and keeps nothing", :aggregate_failures do
      result = call(:add_decision_comment, decision.id, { body: " \n" })

      expect(result.failure).to eq([:invalid, { body: ["blank"] }])
      expect(comments.count).to eq(0)
    end

    it "takes a comment on a closed decision" do
      closed = create(:decision, status: "dropped")

      expect(call(:add_decision_comment, closed.id, { body: "Still unsure" })).to be_success
    end

    it "answers not found for a missing decision" do
      expect(call(:add_decision_comment, 0, { body: "Hello" }).failure).to eq(:not_found)
    end
  end

  describe "editing a comment" do
    it "changes the body in place" do
      edited = call(:edit_decision_comment, decision.id, comment.id, { body: "Leaning on Resque" }).value!

      expect(edited).to have_attributes(id: comment.id, body: "Leaning on Resque")
    end

    it "refuses a blank body and keeps the old one", :aggregate_failures do
      result = call(:edit_decision_comment, decision.id, comment.id, { body: "" })

      expect(result.failure).to eq([:invalid, { body: ["blank"] }])
      expect(comments.by_pk(comment.id).one[:body]).to eq("Leaning on Sidekiq")
    end

    it "answers not found for another decision's comment" do
      stranger = create(:decision_comment)

      expect(call(:edit_decision_comment, decision.id, stranger.id, { body: "Mine" }).failure).to eq(:not_found)
    end
  end

  describe "deleting a comment" do
    it "removes it" do
      call(:delete_decision_comment, decision.id, comment.id)

      expect(comments.by_pk(comment.id).exist?).to be(false)
    end

    it "answers not found for another decision's comment", :aggregate_failures do
      stranger = create(:decision_comment)

      expect(call(:delete_decision_comment, decision.id, stranger.id).failure).to eq(:not_found)
      expect(comments.by_pk(stranger.id).exist?).to be(true)
    end
  end

  describe "photos in a comment" do
    before { connect_media_store }

    def add(body) = call(:add_decision_comment, decision.id, { body: }).value!

    it "claims the photos its body points to" do
      added = add(markdown(photo, other))

      expect(claimed).to contain_exactly([added.id, photo.id], [added.id, other.id])
    end

    it "drops the claim on a photo taken out of its body" do
      added = add(markdown(photo, other))
      call(:edit_decision_comment, decision.id, added.id, { body: markdown(other) })

      expect(claimed).to eq([[added.id, other.id]])
    end

    it "deletes its photos with it", :aggregate_failures, :commits do
      [photo, other].each { stub_request(:delete, media_store_url(it.key)) }
      added = add(markdown(photo, other))
      call(:delete_decision_comment, decision.id, added.id)

      expect(Media::Slice["relations.photos"].count).to eq(0)
      expect(a_request(:delete, media_store_url(other.key))).to have_been_made
    end
  end
end
