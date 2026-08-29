# frozen_string_literal: true

RSpec.describe "Record journal entries", type: :request do
  include Spec::DB::FactoryHelper.new(:record)

  let(:entries) { Record::Slice["relations.journal_entries"] }
  let(:entry) { create(:journal_entry, body: "before") }
  let(:gone_id) { entry.id + 1000 }

  before { sign_in_to_admin }

  def edit(id, body) = post("/admin/journal/#{id}", _csrf_token: admin_csrf_token, entry: { body: })

  def save(body) = post("/admin/journal", _csrf_token: admin_csrf_token, entry: { body: })

  describe "a body only the database finds blank" do
    let(:blank) { " " }

    it "answers 422 and saves nothing" do
      save(blank)

      expect([last_response.status, entries.count]).to eq([422, 0])
    end

    it "answers 422 and keeps the old body on an edit" do
      edit(entry.id, blank)

      expect([last_response.status, entries.by_pk(entry.id).one[:body]]).to eq([422, "before"])
    end
  end

  describe "an entry that has gone" do
    it "answers 404 to an edit and changes nothing" do
      edit(gone_id, "after")

      expect([last_response.status, entries.by_pk(entry.id).one[:body]]).to eq([404, "before"])
    end

    it "answers 404 to a delete and removes nothing" do
      post "/admin/journal/#{gone_id}/delete", _csrf_token: admin_csrf_token

      expect([last_response.status, entries.count]).to eq([404, 1])
    end
  end
end
