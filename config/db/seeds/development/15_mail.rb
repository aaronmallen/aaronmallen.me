# frozen_string_literal: true

require "base64"

mail = Mail::Slice
return if mail["repos.thread_queries"].every_account.any? { it.provider == "gmail" }

gmail = mail["repos.gmail_mutations"]
parse = mail["operations.parse_gmail_thread"]

part = lambda do |type, text|
  data = Base64.urlsafe_encode64(text, padding: false)

  { "mimeType" => type, "filename" => "", "headers" => [{ "name" => "Content-Type", "value" => type }],
    "body" => { "data" => data } }
end

message = lambda do |id, from, subject, text, at, labels|
  headers = { "From" => from, "Subject" => subject }.map { |name, value| { "name" => name, "value" => value } }

  {
    "id" => id, "labelIds" => labels, "internalDate" => (at.to_r * 1000).to_i.to_s,
    "payload" => {
      "mimeType" => "multipart/alternative", "headers" => headers,
      "parts" => [part.call("text/plain", text), part.call("text/html", "<p>#{text}</p>")],
    },
  }
end

{
  "ada@example.com" => [
    [
      "t-lunch", [
        ["Grace Example <grace@example.org>", "Lunch on Thursday?", "Corner Cafe at noon?", 1, %w[INBOX UNREAD]],
        ["Ada Example <ada@example.com>", "Re: Lunch on Thursday?", "Works for me.", 1, %w[SENT]],
      ],
    ],
    [
      "t-receipt",
      [["Example Hardware <orders@hardware.example.com>", "Your order has shipped", "Two tins of eggshell paint.", 4,
        %w[INBOX Label_receipts CATEGORY_UPDATES]]],
    ],
    [
      "t-meetup",
      [["Linus Example <linus@example.net>", "Slides from the meetup", "Here are the Phlex slides.", 6,
        %w[INBOX STARRED IMPORTANT CATEGORY_PERSONAL]]],
    ],
    [
      "t-news",
      [["Ruby Weekly <news@ruby.example.com>", "This week in Ruby", "Hanami 3 ships.", 2,
        %w[UNREAD CATEGORY_PROMOTIONS]]],
    ],
    ["t-draft", [["Ada Example <ada@example.com>", "Notes for the plumber", "The main line again.", 1, %w[DRAFT]]]],
  ],
  "work@example.com" => [
    [
      "t-review",
      [["Ada Example <ada@example.com>", "Design review notes", "Notes from today are in the doc.", 3,
        %w[INBOX UNREAD]]],
    ],
  ],
}.each do |address, threads|
  account = gmail.account(address)
  gmail.store_labels(account.id, [{ gmail_id: "Label_receipts", name: "Receipts" }])

  threads.each do |id, messages|
    raw = messages.each_with_index.map do |(from, subject, text, days_ago, labels), index|
      message.call("#{id}-#{index}", from, subject, text, Seeds.ago(days_ago, hour: 7, minute: index), labels)
    end

    gmail.store_thread(account.id, parse.call({ "id" => id, "messages" => raw }))
  end
end
