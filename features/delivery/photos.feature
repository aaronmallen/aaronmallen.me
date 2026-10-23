Feature: Photos go out with a social post
  Each part's photos come from the media store and go up to the network with their alt text, in the order I saved
  them.

  Background:
    Given the photo "00000000000000000000000000000001.jpg" is 640 by 480
    And the photo "00000000000000000000000000000002.jpg" is 640 by 480
    And the media store holds "00000000000000000000000000000001.jpg"
    And the media store holds "00000000000000000000000000000002.jpg"

  Scenario: Mastodon gets the photos in their saved order with their alt text
    Given a Mastodon account on "ruby.social" is connected
    And a social post due now to "mastodon" in parts:
      | one |
      | two |
    And part 1 of social post 1 shows:
      | key  | alt            |
      | 00000000000000000000000000000002.jpg | A cat on a mat |
      | 00000000000000000000000000000001.jpg |                |
    And Mastodon answers GET "/ruby.social/api/v2/instance" with:
      """
      {"configuration": {"media_attachments": {"image_size_limit": 16777216}}}
      """
    And the network answers POST "/mastodon/ruby.social/api/v2/media" in turn:
      """
      [{"body": {"id": "m1"}}, {"body": {"id": "m2"}}]
      """
    And the network answers POST "/mastodon/ruby.social/api/v1/statuses" in turn:
      """
      [{"body": {"id": "1", "url": "https://ruby.social/@ada/1"}}, {"body": {"id": "2", "url": "https://ruby.social/@ada/2"}}]
      """
    When social post 1 goes out on account 1
    Then the network heard these POST "/ruby.social/api/v1/statuses" bodies:
      | status | media_ids     | in_reply_to_id |
      | one    | ["m1", "m2"] | absent         |
      | two    | absent        | 1              |
    And the network heard POST "/ruby.social/api/v2/media" number 1 holding "photo 00000000000000000000000000000002.jpg"
    And the network heard POST "/ruby.social/api/v2/media" number 1 holding "A cat on a mat"
    And the network heard POST "/ruby.social/api/v2/media" number 1 holding "filename=\"file.jpeg\""
    And the network heard POST "/ruby.social/api/v2/media" number 2 holding "photo 00000000000000000000000000000001.jpg"
    And the network heard POST "/ruby.social/api/v2/media" number 2 without "description"
    And the network heard POST "/ruby.social/api/v2/media" 2 times

  Scenario: A post with no photos asks Mastodon for no photo limit
    Given a Mastodon account on "ruby.social" is connected
    And a social post due now to "mastodon" saying "one"
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "1", "url": "https://ruby.social/@ada/1"}
      """
    When social post 1 goes out on account 1
    Then the delivery on account 1 holds 1 remote ids
    And the network heard GET "/ruby.social/api/v2/instance" 0 times

  Scenario Outline: A photo that cannot go up to Mastodon keeps the error
    Given a Mastodon account on "ruby.social" is connected
    And a social post due now to "mastodon" saying "one"
    And part 1 of social post 1 shows:
      | key  | alt |
      | 00000000000000000000000000000001.jpg |     |
    And Mastodon answers GET "/ruby.social/api/v2/instance" with:
      """
      {"configuration": {"media_attachments": {"image_size_limit": 16777216}}}
      """
    And <trouble>
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "<error>"
    And the network heard POST "/ruby.social/api/v1/statuses" 0 times

    Examples:
      | trouble                                                                 | error                                          |
      | the media store answers GET "/00000000000000000000000000000001.jpg" with status 404 | Photo 00000000000000000000000000000001.jpg is unavailable  |
      | Mastodon answers POST "/ruby.social/api/v2/media" with status 422      | Mastodon answered 422 for POST /api/v2/media   |

  Scenario: A GIF goes up as a GIF and waits until Mastodon has made it ready
    Given the photo "0000000000000000000000000000000a.gif" is 640 by 480
    And the network answers GET "/s3/photos/0000000000000000000000000000000a.gif" in turn:
      """
      [{"body": "gif 0000000000000000000000000000000a.gif", "headers": {"Content-Type": "image/gif"}}]
      """
    And a Mastodon account on "ruby.social" is connected
    And a social post due now to "mastodon" saying "one"
    And part 1 of social post 1 shows:
      | key | alt |
      | 0000000000000000000000000000000a.gif |     |
    And Mastodon answers GET "/ruby.social/api/v2/instance" with:
      """
      {"configuration": {"media_attachments": {"image_size_limit": 16777216}}}
      """
    And the network answers POST "/mastodon/ruby.social/api/v2/media" in turn:
      """
      [{"status": 202, "body": {"id": "m9", "url": null}}]
      """
    And the network answers GET "/mastodon/ruby.social/api/v1/media/m9" in turn:
      """
      [{"status": 206, "body": {"id": "m9", "url": null}}, {"body": {"id": "m9", "url": "https://files/m9.mp4"}}]
      """
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "1", "url": "https://ruby.social/@ada/1"}
      """
    When social post 1 goes out on account 1
    Then the network heard these POST "/ruby.social/api/v1/statuses" bodies:
      | status | media_ids |
      | one    | ["m9"]    |
    And the network heard POST "/ruby.social/api/v2/media" number 1 holding "image/gif"
    And the network heard GET "/ruby.social/api/v1/media/m9" 2 times

  Scenario: A GIF Mastodon never makes ready keeps the error and sends no status
    Given the photo "0000000000000000000000000000000a.gif" is 640 by 480
    And the network answers GET "/s3/photos/0000000000000000000000000000000a.gif" in turn:
      """
      [{"body": "gif 0000000000000000000000000000000a.gif", "headers": {"Content-Type": "image/gif"}}]
      """
    And a Mastodon account on "ruby.social" is connected
    And a social post due now to "mastodon" saying "one"
    And part 1 of social post 1 shows:
      | key | alt |
      | 0000000000000000000000000000000a.gif |     |
    And Mastodon answers GET "/ruby.social/api/v2/instance" with:
      """
      {"configuration": {"media_attachments": {"image_size_limit": 16777216}}}
      """
    And the network answers POST "/mastodon/ruby.social/api/v2/media" in turn:
      """
      [{"status": 202, "body": {"id": "m9", "url": null}}]
      """
    And the network answers GET "/mastodon/ruby.social/api/v1/media/m9" in turn:
      """
      [{"status": 206, "body": {"id": "m9", "url": null}}]
      """
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "Mastodon did not finish processing media m9"
    And the network heard POST "/ruby.social/api/v1/statuses" 0 times

  Scenario: Bluesky gets each photo as a blob, in order with its alt text, and no link card
    Given a Bluesky account "ada.example" is connected
    And a social post due now to "bluesky" saying "read {site}/notes/1"
    And part 1 of social post 1 shows:
      | key  | alt   |
      | 00000000000000000000000000000001.jpg | A cat |
      | 00000000000000000000000000000002.jpg | A dog |
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And the network answers POST "/bluesky/pds/xrpc/com.atproto.repo.uploadBlob" in turn:
      """
      [
        {"body": {"blob": {"$type": "blob", "ref": {"$link": "cid-1"}, "mimeType": "image/jpeg"}}},
        {"body": {"blob": {"$type": "blob", "ref": {"$link": "cid-2"}, "mimeType": "image/jpeg"}}}
      ]
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "cid", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc"}
      """
    When social post 1 goes out on account 1
    Then Bluesky record 1 holds:
      """
      {
        "record": {
          "embed": {
            "$type": "app.bsky.embed.images",
            "images": [
              {"alt": "A cat", "aspectRatio": {"height": 480, "width": 640}, "image": {"ref": {"$link": "cid-1"}}},
              {"alt": "A dog", "aspectRatio": {"height": 480, "width": 640}, "image": {"ref": {"$link": "cid-2"}}}
            ]
          }
        }
      }
      """
    And the network heard POST "/xrpc/com.atproto.repo.uploadBlob" number 1 holding "photo 00000000000000000000000000000001.jpg"
    And the network heard POST "/xrpc/com.atproto.repo.uploadBlob" number 1 with the header "Content-Type" set to "image/jpeg"
    And the network heard POST "/xrpc/com.atproto.repo.uploadBlob" number 1 with the header "Authorization" set to "Bearer jwt"

  Scenario: A photo with no alt text goes to Bluesky with empty alt text, on its own part alone
    Given a Bluesky account "ada.example" is connected
    And a social post due now to "bluesky" in parts:
      | one |
      | two |
    And part 2 of social post 1 shows:
      | key  | alt |
      | 00000000000000000000000000000001.jpg |     |
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.uploadBlob" with:
      """
      {"blob": {"$type": "blob", "ref": {"$link": "cid-1"}, "mimeType": "image/jpeg"}}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "cid", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc"}
      """
    And Bluesky answers GET "/xrpc/com.atproto.repo.getRecord" with:
      """
      {"cid": "cid-one", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc", "value": {}}
      """
    When social post 1 goes out on account 1
    Then Bluesky record 2 holds:
      """
      {"record": {"embed": {"images": [{"alt": ""}]}}}
      """
    And Bluesky record 1 has no "embed"

  Scenario: A photo the media store has lost keeps the error and posts nothing to Bluesky
    Given a Bluesky account "ada.example" is connected
    And a social post due now to "bluesky" saying "one"
    And part 1 of social post 1 shows:
      | key  | alt |
      | 00000000000000000000000000000001.jpg |     |
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And the media store answers GET "/00000000000000000000000000000001.jpg" with status 404
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "Photo 00000000000000000000000000000001.jpg is unavailable"
    And the network heard POST "/xrpc/com.atproto.repo.putRecord" 0 times

  Scenario: An upload Bluesky hands back without a blob keeps the error and posts nothing
    Given a Bluesky account "ada.example" is connected
    And a social post due now to "bluesky" saying "one"
    And part 1 of social post 1 shows:
      | key  | alt |
      | 00000000000000000000000000000001.jpg |     |
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.uploadBlob" with:
      """
      {"size": 1}
      """
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "Bluesky returned no blob for an uploaded image"
    And the network heard POST "/xrpc/com.atproto.repo.putRecord" 0 times
