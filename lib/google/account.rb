# frozen_string_literal: true

module Google
  Account = Data.define(:client, :id) do
    def delete(url) = client.delete(url, account: id)

    def get(url, **) = client.get(url, account: id, **)

    def pages(url, rows:, **) = client.pages(url, rows:, account: id, **)

    def patch(url, body) = client.patch(url, body, account: id)

    def post(url, body, **) = client.post(url, body, account: id, **)

    def work? = client.work?(id)
  end
end
