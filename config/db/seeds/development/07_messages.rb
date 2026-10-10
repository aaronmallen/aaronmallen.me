# frozen_string_literal: true

contact = Contact::Slice
return if Blog::Types::MessageStatus.values.any? { contact["repos.message_queries"].count_with_status(it).positive? }

create_message = contact["operations.create_message"]
hash_visitor = Analytics::Slice["operations.hash_visitor"]

message = lambda do |number, reply_to, subject, body|
  visitor_hashes = hash_visitor.throttle_hashes("192.0.2.#{number}")

  Seeds.unwrap(create_message.call({ reply_to:, subject:, body: }, visitor_hashes:))
end

message.call(21, "reader@example.com", "Loved the Hanami post", "Thanks for the write-up. Did you keep the old URLs?")
read = message.call(22, "friend@example.org", "Lunch next week?", "I am in town on Thursday if you are free.")
spam = message.call(23, "deals@spam.example.net", "You won a prize", "Click the link to claim your prize.")
Seeds.unwrap(contact["operations.mark_message"].call(read.id, "read"))
Seeds.unwrap(contact["operations.mark_message"].call(spam.id, "spam"))
message.call(24, "deals@spam.example.net", "Final notice", "Your prize expires today.")
