# frozen_string_literal: true

RSpec.describe "API revising a post's edit note", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def note_of(edit) = Posts::Slice["relations.post_edits"].by_pk(edit.id).one&.fetch(:note)

  def refusal(message) = { "error" => "invalid", "message" => message, "errors" => { "note" => [message] } }

  def revise(id, edit_id, token: api_token, **fields)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
    patch "/api/v1/posts/#{id}/edits/#{edit_id}", JSON.generate(fields), headers
    JSON.parse(last_response.body)
  end

  def shown(edit)
    saved = Posts::Slice["relations.post_edits"].by_pk(edit.id).one

    { "id" => edit.id, "note" => saved[:note], **%i[created_at updated_at].to_h { [it.to_s, saved[it].utc.iso8601] } }
  end

  def status = last_response.status

  let(:published) { create(:post, :published) }
  let(:edit) { create(:post_edit, post_id: published.id, note: "Fixed a typo") }

  describe "PATCH /api/v1/posts/:id/edits/:edit_id" do
    it "replaces the note" do
      revise(published.id, edit.id, note: "Fixed the benchmark numbers")

      expect(note_of(edit)).to eq("Fixed the benchmark numbers")
    end

    it "answers 200 with the edit, trimmed" do
      answered = revise(published.id, edit.id, note: "  Fixed the benchmark numbers  ")

      expect([answered, status]).to eq([shown(edit).merge("note" => "Fixed the benchmark numbers"), 200])
    end

    it "refuses a blank note with a 422 and keeps the old one", :aggregate_failures do
      expect([revise(published.id, edit.id, note: " "), status])
        .to eq([refusal("note can't be blank: say what changed and why"), 422])
      expect(note_of(edit)).to eq("Fixed a typo")
    end

    it "refuses a note over 500 characters with a 422 and keeps the old one", :aggregate_failures do
      expect([revise(published.id, edit.id, note: "a" * 501), status])
        .to eq([refusal("note runs over 500 characters"), 422])
      expect(note_of(edit)).to eq("Fixed a typo")
    end

    it "takes a note of exactly 500 characters" do
      revise(published.id, edit.id, note: "a" * 500)

      expect([status, note_of(edit)]).to eq([200, "a" * 500])
    end

    it "refuses a note with a control character" do
      expect(revise(published.id, edit.id, note: "Fixed\u0007it"))
        .to eq(refusal("note holds a control character"))
    end

    it "answers 404 for a post that isn't there" do
      expect([revise(999_999, edit.id, note: "Mine"), status]).to eq(
        [{ "error" => "not_found", "message" => "blog post 999999 has no edit with the ID #{edit.id}" }, 404],
      )
    end

    it "answers 404 for an edit that isn't there" do
      expect([revise(published.id, 999_999, note: "Mine"), status]).to eq(
        [{ "error" => "not_found", "message" => "blog post #{published.id} has no edit with the ID 999999" }, 404],
      )
    end

    it "answers another post's edit with a 404 and leaves it alone" do
      stranger = create(:post_edit, note: "Elsewhere")
      revise(published.id, stranger.id, note: "Mine")

      expect([status, note_of(stranger)]).to eq([404, "Elsewhere"])
    end

    it "refuses a request with no note" do
      expect([revise(published.id, edit.id).fetch("errors"), status]).to eq([{ "note" => ["note is missing"] }, 422])
    end

    it "answers 500 when the revision fails some other way" do
      failing = instance_double(Posts::Operations::ReviseEditNote, call: Dry::Monads::Failure(:locked))
      replace_component("posts.operations.revise_edit_note", failing)

      expect([revise(published.id, edit.id, note: "Mine"), status])
        .to eq([{ "error" => "failed", "message" => "could not save the change" }, 500])
    end

    it "refuses a request with no token" do
      revise(published.id, edit.id, note: "Mine", token: nil)

      expect([status, note_of(edit)]).to eq([401, "Fixed a typo"])
    end
  end

  describe "the MCP tool" do
    it "revises as update_post_edit_note does" do
      answered = revise(published.id, edit.id, note: "the same")
      tool = mcp_answer("update_post_edit_note", id: published.id, edit_id: edit.id, note: "the same")

      expect(tool.except("updated_at")).to eq(answered.except("updated_at"))
    end

    it "refuses a blank note with the message the endpoint gives" do
      refused = revise(published.id, edit.id, note: " ")

      expect(mcp_text("update_post_edit_note", id: published.id, edit_id: edit.id, note: " "))
        .to eq(refused.fetch("message"))
    end

    it "refuses an unknown edit with the message the endpoint gives" do
      refused = revise(published.id, 999_999, note: "Mine")

      expect(mcp_text("update_post_edit_note", id: published.id, edit_id: 999_999, note: "Mine"))
        .to eq(refused.fetch("message"))
    end
  end
end
