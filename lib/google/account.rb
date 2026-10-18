# frozen_string_literal: true

module Google
  Account = Data.define(:client, :id) do
    def get(url, **) = client.get(url, account: id, **)

    def pages(url, rows:, **) = client.pages(url, rows:, account: id, **)

    def post(url, body, **) = client.post(url, body, account: id, **)

    def work? = client.work?(id)
  end
end
