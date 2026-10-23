# frozen_string_literal: true

module Mail
  Mailbox = Data.define(:google, :address) do
    def delete(path) = google.delete(url(path), account: address)

    def get(path, **) = google.get(url(path), account: address, **)

    def pages(path, rows:, **) = google.pages(url(path), rows:, account: address, **)

    def post(path, body = {}) = google.post(url(path), body, account: address)

    def put(path, body) = google.put(url(path), body, account: address)

    def thread(gmail_id, format: "full") = get("threads/#{gmail_id}", format:)

    private

    def url(path) = google.url(:gmail, "users/me/#{path}")
  end
end
