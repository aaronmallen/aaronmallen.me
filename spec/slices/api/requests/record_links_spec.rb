# frozen_string_literal: true

RSpec.describe "API record links", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(verb, path, body = nil)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    public_send(verb, "/api/v1/links#{path}", body, headers)
    JSON.parse(last_response.body)
  end

  def commit_link
    id = commit.id

    { "kind" => "commit", "id" => id, "title" => "Move the server", "day" => commit.commit_date.to_date.iso8601 }
      .merge("url" => "/admin/commits/#{id}")
  end

  def link(kind, id, **fields) = call_api(:post, "/#{kind}/#{id}", JSON.generate(fields))

  def link_every_pair
    Blog::Types::RecordKind.values.to_h { [it, linkable_record(it)] }.tap do |records|
      records.keys.combination(2).each do |one, two|
        link(one, records[one].id, other_kind: two, other_id: records[two].id)
      end
    end
  end

  def list(kind, id) = call_api(:get, "/#{kind}/#{id}")

  def status = last_response.status

  def stored = Links::Slice["relations.record_links"].count

  def titles(answered) = answered.fetch("links").transform_values { it.map { it.fetch("title") } }

  def unlink(kind, id, other_kind, other_id) = call_api(:delete, "/#{kind}/#{id}/#{other_kind}/#{other_id}")

  let(:post_record) { create(:post, title: "On hosting") }
  let(:commit) { create(:commit, message: "Move the server") }

  describe "POST /api/v1/links/:kind/:id" do
    it "answers 201 with the record and its links" do
      answered = link("post", post_record.id, other_kind: "commit", other_id: commit.id)

      expect([answered, status])
        .to eq([{ "kind" => "post", "id" => post_record.id, "links" => { "commit" => [commit_link] } }, 201])
    end

    it "stores one link that shows from the other record" do
      link("post", post_record.id, other_kind: "commit", other_id: commit.id)

      expect(list("commit", commit.id).fetch("links").transform_values { it.map { it.fetch("id") } })
        .to eq("post" => [post_record.id])
    end

    it "refuses the same pair twice with a 422 naming the field" do
      link("post", post_record.id, other_kind: "commit", other_id: commit.id)

      expect([link("commit", commit.id, other_kind: "post", other_id: post_record.id).fetch("errors"), status])
        .to eq([{ "other_id" => ["these two records are already linked"] }, 422])
    end

    it "refuses a record linked to itself with a 422" do
      expect(link("post", post_record.id, other_kind: "post", other_id: post_record.id).fetch("message"))
        .to eq("other_id: a record cannot link to itself")
    end

    it "refuses two tasks and points at link_tasks" do
      one, two = Array.new(2) { create(:task) }

      expect(link("task", one.id, other_kind: "task", other_id: two.id).fetch("errors"))
        .to eq("other_id" => ["two tasks take link_tasks, which gives the link a type"])
    end

    it "refuses a record on the other side that is gone with a 422" do
      expect([link("post", post_record.id, other_kind: "commit", other_id: 999_999).fetch("errors"), status])
        .to eq([{ "other_id" => ["that record is gone, so find another"] }, 422])
    end

    it "refuses a kind it does not know with a 422" do
      expect([link("post", post_record.id, other_kind: "person", other_id: 1).fetch("errors").keys, status])
        .to eq([%w[other_kind], 422])
    end

    it "links any two kinds and shows the link from both sides", :aggregate_failures do
      records = link_every_pair

      records.each do |kind, record|
        expect(list(kind, record.id).fetch("links").transform_values { it.map { it.fetch("id") } })
          .to eq(records.except(kind).transform_values { [it.id] })
      end
    end

    it "answers an unknown record with a 404" do
      expect([link("journal_entry", 999_999, other_kind: "commit", other_id: commit.id).fetch("message"), status])
        .to eq(["no journal entry has the ID 999999", 404])
    end
  end

  describe "DELETE /api/v1/links/:kind/:id/:other_kind/:other_id" do
    it "removes the link from whichever side" do
      link("post", post_record.id, other_kind: "commit", other_id: commit.id)

      expect([unlink("commit", commit.id, "post", post_record.id).fetch("links"), status, stored]).to eq([{}, 200, 0])
    end

    it "answers a pair with no link with a 404" do
      expect([unlink("post", post_record.id, "commit", commit.id).fetch("message"), status])
        .to eq(["post #{post_record.id} has no link to commit #{commit.id}", 404])
    end

    it "refuses another kind it does not know with a 422" do
      expect([unlink("post", post_record.id, "person", 1).fetch("errors").keys, status]).to eq([%w[other_kind], 422])
    end

    it "refuses another ID that is not a number with a 422" do
      expect([unlink("post", post_record.id, "commit", "abc").fetch("errors").keys, status]).to eq([%w[other_id], 422])
    end
  end

  describe "GET /api/v1/links/:kind/:id" do
    it "groups a record's links by kind, in the order of the kinds" do
      decision = create(:decision, title: "Pick a host")
      link("decision", decision.id, other_kind: "commit", other_id: commit.id)
      link("decision", decision.id, other_kind: "task", other_id: create(:task, title: "Order the Pi").id)

      expect(titles(list("decision", decision.id))).to eq("task" => ["Order the Pi"], "commit" => ["Move the server"])
    end

    it "answers a record with no links with no groups" do
      expect([list("post", post_record.id).fetch("links"), status]).to eq([{}, 200])
    end

    it "refuses a kind it does not know with a 422" do
      expect([list("person", 1).fetch("errors").keys, status]).to eq([%w[kind], 422])
    end
  end

  describe "the MCP tools" do
    it "link as link_records does" do
      linked = link("post", post_record.id, other_kind: "commit", other_id: commit.id)
      unlink("post", post_record.id, "commit", commit.id)

      expect(mcp_answer("link_records", kind: "post", id: post_record.id, other_kind: "commit", other_id: commit.id))
        .to eq(linked)
    end

    it "unlink as unlink_records does" do
      link("post", post_record.id, other_kind: "commit", other_id: commit.id)
      unlinked = unlink("post", post_record.id, "commit", commit.id)
      link("post", post_record.id, other_kind: "commit", other_id: commit.id)

      expect(mcp_answer("unlink_records", kind: "post", id: post_record.id, other_kind: "commit", other_id: commit.id))
        .to eq(unlinked)
    end

    it "list as list_links does" do
      link("post", post_record.id, other_kind: "commit", other_id: commit.id)

      expect(mcp_answer("list_links", kind: "commit", id: commit.id)).to eq(list("commit", commit.id))
    end

    it "refuse the same pair twice with the message the endpoint gives" do
      link("post", post_record.id, other_kind: "commit", other_id: commit.id)
      refused = link("post", post_record.id, other_kind: "commit", other_id: commit.id)

      expect(mcp_text("link_records", kind: "post", id: post_record.id, other_kind: "commit", other_id: commit.id))
        .to eq(refused.fetch("message"))
    end
  end
end
