# frozen_string_literal: true

RSpec.describe "API mail threads", type: :request do
  def status = last_response.status

  def status_of(message) = Mail::Slice["repos.message_queries"].by_id(message.id).status

  describe "GET /api/v1/mail/threads" do
    it "lists the threads, newest first, with their reply address and no body" do
      message = create(:message)

      threads = call_api(:get, "/mail/threads").fetch("mail_threads")

      expect([threads.map { it.values_at("id", "reply_to", "body") }, status])
        .to eq([[[message.id, message.reply_to, nil]], 200])
    end

    it "answers what list_mail_threads answers, less the untrusted marks" do
      create(:message)

      expect(call_api(:get, "/mail/threads")).to eq(trusted(mcp_answer("list_mail_threads")))
    end

    it "reads no more of the first message's body than its preview" do
      create(:message)

      expect(counting { call_api(:get, "/mail/threads") }.join.scan(/(?<!left\()"body"/)).to be_empty
    end

    it "needs a token with the mail scope" do
      call_api(:get, "/mail/threads", token: api_token(%w[read]))

      expect(status).to eq(403)
    end
  end

  describe "GET /api/v1/mail/threads/:id" do
    it "reads the thread with each message, oldest first" do
      message = create(:message)

      expect([call_api(:get, "/mail/threads/#{message.id}").fetch("messages").map { it.fetch("body") }, status])
        .to eq([[message.body], 200])
    end

    it "answers what read_mail_thread answers, less the untrusted marks" do
      message = create(:message)

      expect(call_api(:get, "/mail/threads/#{message.id}"))
        .to eq(trusted(mcp_answer("read_mail_thread", id: message.id)))
    end

    it "answers an unknown ID with a 404" do
      expect([call_api(:get, "/mail/threads/999999").fetch("message"),
              status]).to eq(["no mail thread has the ID 999999", 404])
    end
  end

  describe "POST /api/v1/mail/threads/:id/mark" do
    it "marks the thread", :aggregate_failures do
      message = create(:message)

      expect([call_api(:post, "/mail/threads/#{message.id}/mark", JSON.generate(status: "spam")), status])
        .to eq([{ "id" => message.id, "status" => "spam" }, 200])
      expect(status_of(message)).to eq("spam")
    end

    it "refuses a status it does not know with a 422" do
      call_api(:post, "/mail/threads/#{create(:message).id}/mark", JSON.generate(status: "lost"))

      expect(status).to eq(422)
    end
  end
end
