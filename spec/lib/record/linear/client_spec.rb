# frozen_string_literal: true

RSpec.describe Record::Linear::Client do
  subject(:client) { Record::Slice["linear.client"] }

  let(:cursor) { Time.utc(2026, 10, 7, 10) }

  before { connect_linear(LinearGraphQL::KEY) }

  def at(minutes) = cursor + (minutes * 60)

  def changed(id = "L_one", updated_at: at(15)) = { id:, updated_at: }

  def history_node(id, *changes, more: false) = { history: linear_history(*changes, more:), id: }

  def move(from, to, minutes) = { at: at(minutes), from:, to: }

  def older_change(request)
    return linear_change("backlog", "started", at: at(-1)) unless
      JSON.parse(request.body).dig("variables", "cursor") == "history-#{at(30).utc.iso8601(3)}"

    linear_change("unstarted", "started", at: at(20))
  end

  def stub_history(*nodes)
    stub_linear(LinearGraphQL::HISTORY_QUERY) do |request|
      ids = JSON.parse(request.body).dig("variables", "ids")
      linear_json(data: { issues: { nodes: nodes.select { ids.include?(it[:id]) } } })
    end
  end

  def transitions(updated_at = at(15)) = client.transitions([changed(updated_at:)], "L_one" => cursor)

  describe "#assigned_issues" do
    it "hands back each issue's updatedAt" do
      stub_linear(LinearGraphQL::ASSIGNED_QUERY, linear_assigned(linear_issue("L_one", updatedAt: at(5).iso8601(3))))

      expect(client.assigned_issues.first[:updated_at]).to eq(at(5))
    end
  end

  describe "#issues" do
    it "hands back each issue's updatedAt" do
      stub_linear(LinearGraphQL::ISSUES_QUERY, linear_issues(linear_issue("L_one", updatedAt: at(5).iso8601(3))))

      expect(client.issues("L_one" => nil).first[:updated_at]).to eq(at(5))
    end
  end

  describe "#transitions" do
    it "hands back each change past the cursor, oldest first, at Linear's time" do
      stub_history(history_node("L_one", linear_change("started", "unstarted", at: at(10)),
                                linear_change("unstarted", "started", at: at(5)),
                                linear_change("backlog", "started", at: at(-5))))

      expect(transitions).to eq("L_one" => [move("open", "started", 5), move("started", "open", 10)])
    end

    it "leaves out a change between two states that map the same" do
      stub_history(history_node("L_one", linear_change("backlog", "unstarted", at: at(5)),
                                linear_change("started", "started", at: at(6))))

      expect(transitions).to eq("L_one" => [])
    end

    it "leaves out a change that moves no state" do
      stub_history(history_node("L_one", linear_change(nil, nil, at: at(5))))

      expect(transitions).to eq("L_one" => [])
    end

    it "sends no history query for an issue not updated past its cursor" do
      stub_history
      cursors = { "L_one" => cursor, "L_two" => cursor }
      client.transitions([changed(updated_at: cursor), changed("L_two", updated_at: nil)], cursors)

      expect(linear_request(LinearGraphQL::HISTORY_QUERY)).not_to have_been_made
    end

    it "sends no history query for an issue with no cursor" do
      stub_history
      client.transitions([changed], {})

      expect(linear_request(LinearGraphQL::HISTORY_QUERY)).not_to have_been_made
    end

    it "asks only for the issues that changed" do
      stub_history(history_node("L_one"))
      client.transitions([changed, changed("L_two", updated_at: cursor)], "L_one" => cursor, "L_two" => cursor)

      expect(linear_request(LinearGraphQL::HISTORY_QUERY, ids: ["L_one"])).to have_been_made.once
    end

    context "with a history longer than one page" do
      before do
        stub_history(history_node("L_one", linear_change("started", "completed", at: at(30)), more: true))
        stub_linear("issue(id:") do |request|
          linear_json(data: { issue: { history: linear_history(older_change(request), more: true) } })
        end
      end

      it "hands back the whole history back to the cursor" do
        expect(transitions(at(30))).to eq("L_one" => [move("open", "started", 20), move("started", "completed", 30)])
      end

      it "stops paging once it reaches the cursor" do
        transitions(at(30))

        expect(linear_request("issue(id:")).to have_been_made.twice
      end
    end

    it "raises Record::RateLimited when Linear rate limits the history" do
      stub_linear(LinearGraphQL::HISTORY_QUERY, linear_errors("RATELIMITED"))

      expect { transitions }.to raise_error(Record::RateLimited)
    end

    it "raises Record::Error when Linear answers with errors" do
      stub_linear(LinearGraphQL::HISTORY_QUERY, linear_errors("INTERNAL"))

      expect { transitions }.to raise_error(Record::Error)
    end
  end
end
