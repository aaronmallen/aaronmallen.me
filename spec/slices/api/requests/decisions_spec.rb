# frozen_string_literal: true

RSpec.describe "API decisions", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(verb, path, fields = nil, token: api_token)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
    public_send(verb, "/api/v1/decisions#{path}", fields && JSON.generate(fields), headers)
    JSON.parse(last_response.body)
  end

  def comments = Decisions::Slice["relations.decision_comments"]

  def events(decision) = Decisions::Slice["relations.decision_events"].where(decision_id: decision.id)

  def options = Decisions::Slice["relations.decision_options"]

  def reload(decision) = Decisions::Slice["queries.by_id"].call(decision.id)

  def status = last_response.status

  def tag(decision, *names) = Decisions::Slice["repos.decision_repo"].replace_tags(decision.id, names)

  let(:decision) { create(:decision, title: "Pick a queue", problem: "Jobs pile up") }
  let(:option) { create(:decision_option, decision_id: decision.id, title: "Sidekiq", body: "Runs today") }

  describe "POST /api/v1/decisions" do
    it "opens a decision and answers 201 with it", :aggregate_failures do
      answered = call_api(:post, "", { title: "Pick a queue", problem: "Jobs pile up", tags: %w[Queues] })

      expect(status).to eq(201)
      expect(answered).to include("title" => "Pick a queue", "problem" => "Jobs pile up", "status" => "open",
                                  "resolved_option_id" => nil, "tags" => ["queues"], "options" => [])
    end

    it "records the opened event" do
      id = call_api(:post, "", { title: "Pick a queue", problem: "Jobs pile up" }).fetch("id")

      expect(Decisions::Slice["relations.decision_events"].where(decision_id: id).pluck(:kind)).to eq(["opened"])
    end

    it "refuses a blank problem with a 422 naming the field" do
      refusal = { "error" => "invalid", "message" => "problem: write the problem down first",
                  "errors" => { "problem" => ["write the problem down first"] } }

      expect([call_api(:post, "", { title: "Pick a queue", problem: " " }), status]).to eq([refusal, 422])
    end

    it "refuses a request with no token" do
      call_api(:post, "", { title: "Pick a queue", problem: "Jobs pile up" }, token: nil)

      expect(status).to eq(401)
    end
  end

  describe "PATCH /api/v1/decisions/:id" do
    it "changes what it names and keeps the rest" do
      answered = call_api(:patch, "/#{decision.id}", { title: "Pick a job queue" })

      expect(answered).to include("title" => "Pick a job queue", "problem" => "Jobs pile up")
    end

    it "edits an open decision's problem with no note" do
      call_api(:patch, "/#{decision.id}", { problem: "Jobs pile up fast" })

      expect([status, reload(decision).problem]).to eq([200, "Jobs pile up fast"])
    end

    it "refuses a closed decision's new problem without a note and keeps the old one", :aggregate_failures do
      closed = create(:decision, status: "dropped", problem: "Jobs pile up")
      answered = call_api(:patch, "/#{closed.id}", { problem: "Jobs pile up fast" })

      expect([answered.fetch("errors"), status])
        .to eq([{ "note" => ["a resolved or dropped decision needs a note to say why it changed"] }, 422])
      expect(reload(closed).problem).to eq("Jobs pile up")
    end

    it "keeps the note on a closed decision's edit" do
      closed = create(:decision, status: "dropped")
      call_api(:patch, "/#{closed.id}", { problem: "Jobs pile up fast", note: "Load grew" })

      expect(events(closed).where(kind: "edited").pluck(:note)).to eq(["Load grew"])
    end

    it "answers an unknown decision with a 404" do
      expect([call_api(:patch, "/999999", { title: "Gone" }), status])
        .to eq([{ "error" => "not_found", "message" => "no decision has the ID 999999" }, 404])
    end

    it "refuses a request with no token" do
      call_api(:patch, "/#{decision.id}", { title: "Pick a job queue" }, token: nil)

      expect([status, reload(decision).title]).to eq([401, "Pick a queue"])
    end
  end

  describe "POST /api/v1/decisions/:id/resolve" do
    it "resolves the decision with its own option" do
      answered = call_api(:post, "/#{decision.id}/resolve", { option_id: option.id, reason: "It runs today" })

      expect(answered).to include("status" => "resolved", "resolved_option_id" => option.id)
    end

    it "answers with the decision's options" do
      answered = call_api(:post, "/#{decision.id}/resolve", { option_id: option.id, reason: "It runs today" })

      expect(answered.fetch("options").map { it.slice("id", "title", "body") })
        .to eq([{ "id" => option.id, "title" => "Sidekiq", "body" => "Runs today" }])
    end

    it "refuses another decision's option with a field error and leaves it open", :aggregate_failures do
      stranger = create(:decision_option)
      answered = call_api(:post, "/#{decision.id}/resolve", { option_id: stranger.id, reason: "It runs" })

      expect([answered.fetch("errors"), status])
        .to eq([{ "option_id" => ["pick one of this decision's own options"] }, 422])
      expect(reload(decision).status).to eq("open")
    end

    it "refuses a blank reason" do
      answered = call_api(:post, "/#{decision.id}/resolve", { option_id: option.id, reason: "" })

      expect(answered.fetch("errors")).to eq("reason" => ["write down why first"])
    end

    it "refuses a decision that is already closed" do
      closed = create(:decision, status: "dropped")
      choice = create(:decision_option, decision_id: closed.id)

      expect(call_api(:post, "/#{closed.id}/resolve", { option_id: choice.id, reason: "Now" }).fetch("errors"))
        .to eq("id" => ["decision #{closed.id} is already resolved or dropped"])
    end

    it "refuses a request with no token" do
      call_api(:post, "/#{decision.id}/resolve", { option_id: option.id, reason: "It runs" }, token: nil)

      expect([status, reload(decision).status]).to eq([401, "open"])
    end
  end

  describe "POST /api/v1/decisions/:id/drop" do
    it "drops the decision with no choice" do
      expect(call_api(:post, "/#{decision.id}/drop", { reason: "Not needed" }))
        .to include("status" => "dropped", "resolved_option_id" => nil)
    end

    it "refuses a request with no reason" do
      expect([call_api(:post, "/#{decision.id}/drop", {}).fetch("errors"), status])
        .to eq([{ "reason" => ["reason is missing"] }, 422])
    end

    it "refuses a request with no token" do
      call_api(:post, "/#{decision.id}/drop", { reason: "Not needed" }, token: nil)

      expect(status).to eq(401)
    end
  end

  describe "POST /api/v1/decisions/:id/reopen" do
    it "reopens a resolved decision and clears the choice" do
      call_api(:post, "/#{decision.id}/resolve", { option_id: option.id, reason: "It runs today" })

      expect(call_api(:post, "/#{decision.id}/reopen", { reason: "Load grew" }))
        .to include("status" => "open", "resolved_option_id" => nil)
    end

    it "refuses an open decision" do
      expect(call_api(:post, "/#{decision.id}/reopen", { reason: "Again" }).fetch("errors"))
        .to eq("id" => ["decision #{decision.id} is already open"])
    end

    it "refuses a request with no token" do
      call_api(:post, "/#{decision.id}/reopen", { reason: "Load grew" }, token: nil)

      expect(status).to eq(401)
    end
  end

  describe "POST /api/v1/decisions/:id/options" do
    it "adds the option and answers 201 with it", :aggregate_failures do
      answered = call_api(:post, "/#{decision.id}/options", { title: "Resque", body: "Runs on **Redis**" })

      expect(status).to eq(201)
      expect(answered).to include("title" => "Resque", "body" => "Runs on **Redis**")
    end

    it "takes an option with no body" do
      expect(call_api(:post, "/#{decision.id}/options", { title: "Do nothing" }).fetch("body")).to eq("")
    end

    it "refuses a closed decision" do
      closed = create(:decision, status: "dropped")

      expect(call_api(:post, "/#{closed.id}/options", { title: "Resque" }).fetch("errors"))
        .to eq("id" => ["decision #{closed.id} is resolved or dropped, so reopen it to add an option"])
    end

    it "answers an unknown decision with a 404" do
      call_api(:post, "/999999/options", { title: "Resque" })

      expect(status).to eq(404)
    end

    it "refuses a request with no token" do
      call_api(:post, "/#{decision.id}/options", { title: "Resque" }, token: nil)

      expect([status, options.count]).to eq([401, 0])
    end
  end

  describe "PATCH /api/v1/decisions/:id/options/:option_id" do
    it "changes what it names and keeps the rest" do
      expect(call_api(:patch, "/#{decision.id}/options/#{option.id}", { title: "Sidekiq 8" }))
        .to include("title" => "Sidekiq 8", "body" => "Runs today")
    end

    it "refuses an edit on a closed decision without a note" do
      closed = create(:decision, status: "dropped")
      choice = create(:decision_option, decision_id: closed.id)

      expect(call_api(:patch, "/#{closed.id}/options/#{choice.id}", { title: "Renamed" }).fetch("errors"))
        .to eq("note" => ["a resolved or dropped decision needs a note to say why it changed"])
    end

    it "answers another decision's option with a 404" do
      stranger = create(:decision_option)

      message = "decision #{decision.id} has no option with the ID #{stranger.id}"

      expect([call_api(:patch, "/#{decision.id}/options/#{stranger.id}", { title: "Mine" }), status])
        .to eq([{ "error" => "not_found", "message" => message }, 404])
    end

    it "refuses a request with no token" do
      call_api(:patch, "/#{decision.id}/options/#{option.id}", { title: "Sidekiq 8" }, token: nil)

      expect(status).to eq(401)
    end
  end

  describe "DELETE /api/v1/decisions/:id/options/:option_id" do
    it "deletes the option" do
      answered = call_api(:delete, "/#{decision.id}/options/#{option.id}")

      expect([answered, options.by_pk(option.id).exist?])
        .to eq([{ "id" => decision.id, "option_id" => option.id, "deleted" => true }, false])
    end

    it "refuses the option the decision was resolved with" do
      call_api(:post, "/#{decision.id}/resolve", { option_id: option.id, reason: "It runs today" })

      expect([call_api(:delete, "/#{decision.id}/options/#{option.id}").fetch("errors"), status])
        .to eq([{ "option_id" => ["the decision was resolved with this option, so reopen it first"] }, 422])
    end

    it "refuses a request with no token" do
      call_api(:delete, "/#{decision.id}/options/#{option.id}", token: nil)

      expect([status, options.by_pk(option.id).exist?]).to eq([401, true])
    end
  end

  describe "the comment endpoints" do
    let(:comment) { create(:decision_comment, decision_id: decision.id, body: "Leaning on Sidekiq") }

    it "adds a comment and answers 201 with it", :aggregate_failures do
      answered = call_api(:post, "/#{decision.id}/comments", { body: "  Leaning on Sidekiq " })

      expect(status).to eq(201)
      expect(answered).to include("body" => "Leaning on Sidekiq")
    end

    it "refuses a blank comment" do
      expect(call_api(:post, "/#{decision.id}/comments", { body: " " }).fetch("errors"))
        .to eq("body" => ["write the comment first"])
    end

    it "edits a comment" do
      answered = call_api(:patch, "/#{decision.id}/comments/#{comment.id}", { body: "Leaning on Resque" })

      expect(answered).to include("id" => comment.id, "body" => "Leaning on Resque")
    end

    it "answers another decision's comment with a 404" do
      stranger = create(:decision_comment)
      call_api(:patch, "/#{decision.id}/comments/#{stranger.id}", { body: "Mine" })

      expect(status).to eq(404)
    end

    it "deletes a comment" do
      answered = call_api(:delete, "/#{decision.id}/comments/#{comment.id}")

      expect([answered, comments.by_pk(comment.id).exist?])
        .to eq([{ "id" => decision.id, "comment_id" => comment.id, "deleted" => true }, false])
    end

    it "refuses a new comment with no token" do
      call_api(:post, "/#{decision.id}/comments", { body: "Hi" }, token: nil)

      expect([status, comments.count]).to eq([401, 0])
    end

    it "refuses an edit with no token" do
      call_api(:patch, "/#{decision.id}/comments/#{comment.id}", { body: "Hi" }, token: nil)

      expect([status, comments.by_pk(comment.id).one[:body]]).to eq([401, "Leaning on Sidekiq"])
    end

    it "refuses a delete with no token" do
      call_api(:delete, "/#{decision.id}/comments/#{comment.id}", token: nil)

      expect([status, comments.by_pk(comment.id).exist?]).to eq([401, true])
    end
  end

  describe "the tag endpoints" do
    it "adds tags and keeps the ones it has", :aggregate_failures do
      tag(decision, "queues")
      answered = call_api(:post, "/#{decision.id}/tags", { tags: %w[Ruby queues] })

      expect(status).to eq(201)
      expect(answered.fetch("tags")).to contain_exactly("queues", "ruby")
    end

    it "tags a closed decision with no note" do
      closed = create(:decision, status: "dropped")

      expect(call_api(:post, "/#{closed.id}/tags", { tags: %w[ruby] }).fetch("tags")).to eq(["ruby"])
    end

    it "refuses a tag that is not lowercase words" do
      expect(call_api(:post, "/#{decision.id}/tags", { tags: ["no way!"] }).fetch("errors"))
        .to eq("tags" => ["tags are lowercase words"])
    end

    it "takes one tag off" do
      tag(decision, "queues", "ruby")

      expect(call_api(:delete, "/#{decision.id}/tags/queues").fetch("tags")).to eq(["ruby"])
    end

    it "answers a tag the decision does not carry with a 404" do
      expect([call_api(:delete, "/#{decision.id}/tags/queues"), status])
        .to eq([{ "error" => "not_found", "message" => "decision #{decision.id} has no tag queues" }, 404])
    end

    it "refuses a new tag with no token" do
      call_api(:post, "/#{decision.id}/tags", { tags: %w[ruby] }, token: nil)

      expect([status, reload(decision).tags]).to eq([401, []])
    end

    it "refuses to take a tag off with no token" do
      tag(decision, "queues")
      call_api(:delete, "/#{decision.id}/tags/queues", token: nil)

      expect([status, reload(decision).tags.map(&:name)]).to eq([401, ["queues"]])
    end
  end

  describe "the MCP tools" do
    it "opens a decision as open_decision does" do
      answered = call_api(:post, "", { title: "Pick a queue", problem: "Jobs pile up" })
      stamps = %w[id created_at updated_at]

      expect(mcp_answer("open_decision", title: "Pick a queue", problem: "Jobs pile up").except(*stamps))
        .to eq(answered.except(*stamps))
    end

    it "refuses a closed decision's edit without a note, as the admin does", :aggregate_failures do
      call_api(:post, "/#{decision.id}/resolve", { option_id: option.id, reason: "It runs today" })

      expect(mcp_text("edit_decision", id: decision.id, problem: "Jobs pile up fast"))
        .to eq("note: a resolved or dropped decision needs a note to say why it changed")
      expect(reload(decision).problem).to eq("Jobs pile up")
    end

    it "refuses to resolve with another decision's option, naming the field" do
      stranger = create(:decision_option)

      expect(mcp_text("resolve_decision", id: decision.id, option_id: stranger.id, reason: "It runs"))
        .to eq("option_id: pick one of this decision's own options")
    end

    it "tags and untags a decision" do
      mcp_answer("tag_decision", id: decision.id, tags: %w[queues ruby])

      expect(mcp_answer("untag_decision", id: decision.id, tag: "ruby").fetch("tags")).to eq(["queues"])
    end

    it "comments, edits and deletes as the endpoints do" do
      added = mcp_answer("add_decision_comment", id: decision.id, body: "Leaning on Sidekiq")
      mcp_answer("edit_decision_comment", id: decision.id, comment_id: added.fetch("id"), body: "Resque")

      expect(mcp_answer("delete_decision_comment", id: decision.id, comment_id: added.fetch("id")))
        .to eq("id" => decision.id, "comment_id" => added.fetch("id"), "deleted" => true)
    end
  end
end
