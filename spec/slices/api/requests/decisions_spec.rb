# frozen_string_literal: true

RSpec.describe "API decisions", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def at(hour) = Blog::TimeZone.local_time(2026, 9, 1, hour, 0)

  def call_api(verb, path, fields = nil)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    public_send(verb, "/api/v1/decisions#{path}", fields && JSON.generate(fields), headers)
    JSON.parse(last_response.body)
  end

  def comments = Decisions::Slice["relations.decision_comments"]

  def event(decision, kind, hour, **)
    create(:decision_event, decision_id: decision.id, kind:, created_at: at(hour), **)
  end

  def events(decision) = Decisions::Slice["relations.decision_events"].where(decision_id: decision.id)

  def link(kind, id, other_kind, other_id)
    Links::Slice["operations.link_records"].call(kind, id, { other_kind:, other_id: }).value!
  end

  def list(query = "") = call_api(:get, "?#{query}")

  def listed(query = "") = list(query).fetch("decisions").map { it.fetch("id") }

  def options = Decisions::Slice["relations.decision_options"]

  def read(id) = call_api(:get, "/#{id}")

  def record_history
    event(decision, "opened", 8)
    event(decision, "option_added", 9, option_id: option.id)
    event(decision, "resolved", 11, option_id: option.id, reason: "It runs today")
    event(decision, "reopened", 12, reason: "Load grew")
    event(decision, "edited", 13, note: "Load grew more")
  end

  def reload(decision) = Decisions::Slice["queries.by_id"].call(decision.id)

  def status = last_response.status

  def tag(decision, *names) = Decisions::Slice["repos.decision_repo"].replace_tags(decision.id, names)

  def whole_timeline
    [
      { "kind" => "opened", "option_id" => nil, "reason" => nil, "note" => nil },
      { "kind" => "option_added", "option_id" => option.id, "reason" => nil, "note" => nil },
      { "kind" => "comment", "body" => "Ask ops first" },
      { "kind" => "resolved", "option_id" => option.id, "reason" => "It runs today", "note" => nil },
      { "kind" => "reopened", "option_id" => nil, "reason" => "Load grew", "note" => nil },
      { "kind" => "edited", "option_id" => nil, "reason" => nil, "note" => "Load grew more" },
    ]
  end

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

    it "records no event for an edit that changes nothing" do
      call_api(:patch, "/#{decision.id}", { title: "Pick a queue", problem: "Jobs pile up" })

      expect([status, events(decision).count]).to eq([200, 0])
    end

    it "refuses a note over 500 characters" do
      closed = create(:decision, status: "dropped")
      call_api(:patch, "/#{closed.id}", { problem: "Jobs pile up fast", note: "a" * 501 })

      expect([status, events(closed).count]).to eq([422, 0])
    end

    it "answers an unknown decision with a 404" do
      expect([call_api(:patch, "/999999", { title: "Gone" }), status])
        .to eq([{ "error" => "not_found", "message" => "no decision has the ID 999999" }, 404])
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

    it "answers an unknown decision with a 404" do
      call_api(:post, "/999999/resolve", { option_id: option.id, reason: "It runs today" })

      expect(status).to eq(404)
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

    it "records no event for an option edit that changes nothing" do
      call_api(:patch, "/#{decision.id}/options/#{option.id}", { title: "Sidekiq", body: "Runs today" })

      expect([status, events(decision).count]).to eq([200, 0])
    end

    it "answers another decision's option with a 404" do
      stranger = create(:decision_option)

      message = "decision #{decision.id} has no option with the ID #{stranger.id}"

      expect([call_api(:patch, "/#{decision.id}/options/#{stranger.id}", { title: "Mine" }), status])
        .to eq([{ "error" => "not_found", "message" => message }, 404])
    end
  end

  describe "DELETE /api/v1/decisions/:id/options/:option_id" do
    it "deletes the option" do
      answered = call_api(:delete, "/#{decision.id}/options/#{option.id}")

      expect([answered, options.by_pk(option.id).exist?])
        .to eq([{ "id" => decision.id, "option_id" => option.id, "deleted" => true }, false])
    end

    it "answers another decision's option with a 404" do
      call_api(:delete, "/#{decision.id}/options/#{create(:decision_option).id}")

      expect(status).to eq(404)
    end

    it "deletes the option's events with it" do
      added = call_api(:post, "/#{decision.id}/options", { title: "Resque" }).fetch("id")
      call_api(:delete, "/#{decision.id}/options/#{added}")

      expect(events(decision).where(option_id: added).count).to eq(0)
    end

    it "deletes an option once chosen after the decision reopens" do
      call_api(:post, "/#{decision.id}/resolve", { option_id: option.id, reason: "It runs today" })
      call_api(:post, "/#{decision.id}/reopen", { reason: "Load grew" })
      call_api(:delete, "/#{decision.id}/options/#{option.id}")

      expect([status, options.by_pk(option.id).exist?]).to eq([200, false])
    end

    it "refuses the option the decision was resolved with" do
      call_api(:post, "/#{decision.id}/resolve", { option_id: option.id, reason: "It runs today" })

      expect([call_api(:delete, "/#{decision.id}/options/#{option.id}").fetch("errors"), status])
        .to eq([{ "option_id" => ["the decision was resolved with this option, so reopen it first"] }, 422])
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
  end

  describe "GET /api/v1/decisions" do
    let!(:open_one) { create(:decision, created_at: at(9)) }
    let!(:dropped) { create(:decision, status: "dropped", created_at: at(10)) }

    it "lists every decision, newest first, when no filter is given" do
      expect(listed).to eq([dropped.id, open_one.id])
    end

    it "narrows the list by status" do
      expect(listed("status=dropped")).to eq([dropped.id])
    end

    it "narrows the list by tag" do
      tag(open_one, "queues")
      tag(dropped, "ruby")

      expect(listed("tag=Queues")).to eq([open_one.id])
    end

    it "narrows the list by status and tag together" do
      tag(open_one, "queues")
      tag(dropped, "queues")

      expect(listed("status=open&tag=queues")).to eq([open_one.id])
    end

    it "answers each decision with its options and tags" do
      create(:decision_option, decision_id: open_one.id, title: "Sidekiq")
      tag(open_one, "queues")

      expect(list("status=open").fetch("decisions").first)
        .to include("tags" => ["queues"], "options" => [include("title" => "Sidekiq")])
    end

    it "counts the page and says when no more remain" do
      expect(list).to include("count" => 2, "partial" => false)
    end

    it "pages the decisions" do
      lower_page_size(:mcp, to: 1)

      expect([listed, list.slice("partial", "next_page"), listed("page=2")])
        .to eq([[dropped.id], { "partial" => true, "next_page" => 2 }, [open_one.id]])
    end

    it "refuses an unknown status with a 422 naming the field" do
      expect([list("status=done").fetch("errors").keys, status]).to eq([["status"], 422])
    end
  end

  describe "GET /api/v1/decisions/:id" do
    it "answers the decision with its problem, status and dates" do
      dates = { "created_at" => String, "updated_at" => String }

      expect(read(decision.id)).to include("title" => "Pick a queue", "problem" => "Jobs pile up", **dates)
    end

    it "answers the decision with its options and tags" do
      option
      tag(decision, "queues")

      expect(read(decision.id)).to include("tags" => ["queues"], "options" => [include("title" => "Sidekiq")])
    end

    it "answers no choice for an open decision" do
      expect(read(decision.id).fetch("choice")).to be_nil
    end

    it "answers the chosen option and the reason it won", :aggregate_failures do
      call_api(:post, "/#{decision.id}/resolve", { option_id: option.id, reason: "It runs today" })
      choice = read(decision.id).fetch("choice")

      expect(choice).to include("reason" => "It runs today", "option" => include("id" => option.id))
      expect(Time.iso8601(choice.fetch("resolved_at"))).to be_within(60).of(Time.now)
    end

    it "answers the latest reason when the decision was resolved again" do
      call_api(:post, "/#{decision.id}/resolve", { option_id: option.id, reason: "It runs today" })
      call_api(:post, "/#{decision.id}/reopen", { reason: "Load grew" })
      call_api(:post, "/#{decision.id}/resolve", { option_id: option.id, reason: "Still the best" })

      expect(read(decision.id).dig("choice", "reason")).to eq("Still the best")
    end

    it "answers the comments, oldest first, with their dates" do
      create(:decision_comment, decision_id: decision.id, body: "second", created_at: at(14))
      create(:decision_comment, decision_id: decision.id, body: "first", created_at: at(9))

      first = include("body" => "first", "created_at" => at(9).utc.iso8601, "updated_at" => String)

      expect(read(decision.id).fetch("comments")).to match([first, include("body" => "second")])
    end

    it "answers the records linked to it, the tasks that carry it out among them" do
      task = create(:task, title: "Set up Sidekiq")
      link("decision", decision.id, "task", task.id)

      expect(read(decision.id).fetch("record_links"))
        .to match("task" => [include("kind" => "task", "id" => task.id, "title" => "Set up Sidekiq")])
    end

    it "answers no record links for a decision with none" do
      expect(read(decision.id).fetch("record_links")).to eq({})
    end

    it "answers the whole timeline, oldest first" do
      record_history
      create(:decision_comment, decision_id: decision.id, body: "Ask ops first", created_at: at(10))

      expect(read(decision.id).fetch("timeline").map { it.slice("kind", "option_id", "reason", "note", "body") })
        .to eq(whole_timeline)
    end

    it "gives each timeline entry its ID and time" do
      comment = create(:decision_comment, decision_id: decision.id, created_at: at(10))

      expect(read(decision.id).fetch("timeline"))
        .to match([include("kind" => "comment", "id" => comment.id, "occurred_at" => at(10).utc.iso8601)])
    end

    it "answers an unknown decision with a 404" do
      expect([read(999_999), status])
        .to eq([{ "error" => "not_found", "message" => "no decision has the ID 999999" }, 404])
    end
  end

  describe "the MCP tools" do
    it "lists decisions as list_decisions does" do
      create(:decision)

      expect(mcp_answer("list_decisions", status: "open")).to eq(list("status=open"))
    end

    it "reads a decision as read_decision does" do
      call_api(:post, "/#{decision.id}/resolve", { option_id: option.id, reason: "It runs today" })

      expect(mcp_answer("read_decision", id: decision.id)).to eq(read(decision.id))
    end

    it "refuses an unknown decision in read_decision" do
      expect(mcp_text("read_decision", id: 999_999)).to eq("no decision has the ID 999999")
    end

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
