Feature: What a social post sends to LinkedIn
  LinkedIn gets one public post as the member, the thread's parts joined by blank lines, with its photos uploaded
  first. LinkedIn hands back the new post's id in a header.

  Background:
    Given a LinkedIn account is connected

  Scenario: A post goes out in public as the member and links to the new post
    Given a social post due now to "linkedin" saying "hello"
    And the network answers POST "/linkedin/api/rest/posts" in turn:
      """
      [{"status": 201, "headers": {"x-restli-id": "urn:li:share:7"}}]
      """
    When social post 1 goes out on account 1
    Then the network heard these POST "/rest/posts" bodies:
      | author                   | commentary | visibility | lifecycleState |
      | urn:li:person:member-ada | hello      | PUBLIC     | PUBLISHED      |
    And the network heard POST "/rest/posts" with the header "Authorization" set to "Bearer linkedin-token"
    And the network heard POST "/rest/posts" with the header "LinkedIn-Version" set to "202609"
    And the network heard POST "/rest/posts" with the header "X-Restli-Protocol-Version" set to "2.0.0"
    And the social_post_deliveries table has a row with:
      | remote_ids       | remote_url                                            | error |
      | {urn:li:share:7} | https://www.linkedin.com/feed/update/urn:li:share:7/ | null  |

  Scenario Outline: LinkedIn gets its reserved characters escaped and mentions as names
    Given the people table holds:
      | key | name         | mastodon_handle  |
      | ada | Ada Lovelace | @ada@ruby.social |
    And a social post due now to "linkedin" saying "<written>"
    And the network answers POST "/linkedin/api/rest/posts" in turn:
      """
      [{"status": 201, "headers": {"x-restli-id": "urn:li:share:7"}}]
      """
    When social post 1 goes out on account 1
    Then the network heard these POST "/rest/posts" bodies:
      | commentary |
      | <sent>     |

    Examples:
      | written             | sent                           |
      | a (b) [c] *d* #ruby | a \\(b\\) \\[c\\] \\*d\\* #ruby |
      | hi @{ada}           | hi Ada Lovelace                |

  Scenario: A thread goes to LinkedIn as one post
    Given a social post due now to "linkedin" in parts:
      | one   |
      | two   |
      | three |
    And the network answers POST "/linkedin/api/rest/posts" in turn:
      """
      [{"status": 201, "headers": {"x-restli-id": "urn:li:share:7"}}]
      """
    When social post 1 goes out on account 1
    Then the network heard these POST "/rest/posts" bodies:
      | commentary              |
      | one\n\ntwo\n\nthree |
    And the social_posts table has a row with:
      | id | status |
      | 1  | posted |

  Scenario: One post goes out to Mastodon, Bluesky and LinkedIn and links each delivery to its post
    Given a Mastodon account on "ruby.social" is connected
    And a Bluesky account "ada.example" is connected
    And a social post due now to "mastodon bluesky linkedin" saying "hello"
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "110", "url": "https://ruby.social/@ada/110"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "cid", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc"}
      """
    And the network answers POST "/linkedin/api/rest/posts" in turn:
      """
      [{"status": 201, "headers": {"x-restli-id": "urn:li:share:7"}}]
      """
    When social post 1 goes out on account 1
    And social post 1 goes out on account 2
    And social post 1 goes out on account 3
    Then the social_posts table has a row with:
      | id | status |
      | 1  | posted |
    And the social_post_deliveries table has a row with:
      | network  | remote_url                   |
      | mastodon | https://ruby.social/@ada/110 |
    And the social_post_deliveries table has a row with:
      | network | remote_url                                      |
      | bluesky | https://bsky.app/profile/ada.example/post/3kabc |
    And the social_post_deliveries table has a row with:
      | network  | remote_url                                            |
      | linkedin | https://www.linkedin.com/feed/update/urn:li:share:7/ |

  Scenario: A post that LinkedIn first times out on fails for good without leave to read the member's posts
    Given a social post due now to "linkedin" saying "hello"
    And the network answers POST "/linkedin/api/rest/posts" in turn:
      """
      [{"delay": 15000, "status": 201}]
      """
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "timed out"
    And the social_post_deliveries table has a row with:
      | failed |
      | true   |
    And the social job "Social::Jobs::DeliverSocialPost" finishes without an error

  Scenario: A claimed delivery posts on its first send without looking at recent posts
    Given a social post due now to "linkedin" saying "hello"
    And the deliveries of social post 1 are:
      | network  | connection_id |
      | linkedin | 1             |
    And LinkedIn answers GET "/rest/posts" with:
      """
      {"elements": [{"id": "urn:li:share:0", "commentary": "hello"}]}
      """
    And the network answers POST "/linkedin/api/rest/posts" in turn:
      """
      [{"status": 201, "headers": {"x-restli-id": "urn:li:share:9"}}]
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | remote_ids       |
      | {urn:li:share:9} |
    And the network heard GET "/rest/posts" 0 times

  Scenario: The photos go up for the member and show on the post with their alt text
    Given the photo "00000000000000000000000000000001.jpg" is 640 by 480
    And the photo "00000000000000000000000000000002.jpg" is 640 by 480
    And the media store holds "00000000000000000000000000000001.jpg"
    And the media store holds "00000000000000000000000000000002.jpg"
    And a social post due now to "linkedin" saying "one"
    And part 1 of social post 1 shows:
      | key  | alt   |
      | 00000000000000000000000000000001.jpg | A cat |
      | 00000000000000000000000000000002.jpg | A dog |
    And the network answers POST "/linkedin/api/rest/images?action=initializeUpload" in turn:
      """
      [
        {"body": {"value": {"image": "urn:li:image:1", "uploadUrl": "http://203.0.113.9/up/1"}}},
        {"body": {"value": {"image": "urn:li:image:2", "uploadUrl": "http://203.0.113.9/up/2"}}}
      ]
      """
    And the web answers PUT "http://203.0.113.9/up/1" with status 201
    And the web answers PUT "http://203.0.113.9/up/2" with status 201
    And the network answers POST "/linkedin/api/rest/posts" in turn:
      """
      [{"status": 201, "headers": {"x-restli-id": "urn:li:share:7"}}]
      """
    When social post 1 goes out on account 1
    Then the network heard these POST "/rest/posts" bodies:
      | content                                                                                                       |
      | {"multiImage": {"images": [{"altText": "A cat", "id": "urn:li:image:1"}, {"altText": "A dog", "id": "urn:li:image:2"}]}} |
    And the network heard these POST "/rest/images" bodies:
      | initializeUploadRequest                 |
      | {"owner": "urn:li:person:member-ada"} |
      | {"owner": "urn:li:person:member-ada"} |
    And the network heard POST "/rest/images" with the header "Authorization" set to "Bearer linkedin-token"
    And the network heard PUT "/up/1" number 1 holding "photo 00000000000000000000000000000001.jpg"
    And the network heard PUT "/up/1" number 1 with the header "Content-Type" set to "image/jpeg"
    And the network heard PUT "/up/1" number 1 with the header "Authorization" set to "Bearer linkedin-token"

  Scenario Outline: One photo shows as the post's image
    Given the photo "00000000000000000000000000000001.jpg" is 640 by 480
    And the media store holds "00000000000000000000000000000001.jpg"
    And a social post due now to "linkedin" saying "one"
    And part 1 of social post 1 shows:
      | key  | alt   |
      | 00000000000000000000000000000001.jpg | <alt> |
    And the network answers POST "/linkedin/api/rest/images?action=initializeUpload" in turn:
      """
      [{"body": {"value": {"image": "urn:li:image:1", "uploadUrl": "http://203.0.113.9/up/1"}}}]
      """
    And the web answers PUT "http://203.0.113.9/up/1" with status 201
    And the network answers POST "/linkedin/api/rest/posts" in turn:
      """
      [{"status": 201, "headers": {"x-restli-id": "urn:li:share:7"}}]
      """
    When social post 1 goes out on account 1
    Then the network heard these POST "/rest/posts" bodies:
      | content   |
      | <content> |

    Examples:
      | alt   | content                                                |
      | A cat | {"media": {"altText": "A cat", "id": "urn:li:image:1"}} |
      |       | {"media": {"id": "urn:li:image:1"}}                    |

  Scenario: A thread's photos go on its one post, up to four
    Given the photo "00000000000000000000000000000001.jpg" is 640 by 480
    And the photo "00000000000000000000000000000002.jpg" is 640 by 480
    And the photo "00000000000000000000000000000003.jpg" is 640 by 480
    And the photo "00000000000000000000000000000004.jpg" is 640 by 480
    And the photo "00000000000000000000000000000005.jpg" is 640 by 480
    And the media store holds "00000000000000000000000000000001.jpg"
    And the media store holds "00000000000000000000000000000002.jpg"
    And the media store holds "00000000000000000000000000000003.jpg"
    And the media store holds "00000000000000000000000000000004.jpg"
    And the media store holds "00000000000000000000000000000005.jpg"
    And a social post due now to "linkedin" in parts:
      | one |
      | two |
    And part 1 of social post 1 shows:
      | key  | alt |
      | 00000000000000000000000000000001.jpg |     |
      | 00000000000000000000000000000002.jpg |     |
      | 00000000000000000000000000000003.jpg |     |
    And part 2 of social post 1 shows:
      | key  | alt |
      | 00000000000000000000000000000004.jpg |     |
      | 00000000000000000000000000000005.jpg |     |
    And the network answers POST "/linkedin/api/rest/images?action=initializeUpload" in turn:
      """
      [
        {"body": {"value": {"image": "urn:li:image:1", "uploadUrl": "http://203.0.113.9/up/1"}}},
        {"body": {"value": {"image": "urn:li:image:2", "uploadUrl": "http://203.0.113.9/up/2"}}},
        {"body": {"value": {"image": "urn:li:image:3", "uploadUrl": "http://203.0.113.9/up/3"}}},
        {"body": {"value": {"image": "urn:li:image:4", "uploadUrl": "http://203.0.113.9/up/4"}}}
      ]
      """
    And the web answers PUT "http://203.0.113.9/up/1" with status 201
    And the web answers PUT "http://203.0.113.9/up/2" with status 201
    And the web answers PUT "http://203.0.113.9/up/3" with status 201
    And the web answers PUT "http://203.0.113.9/up/4" with status 201
    And the network answers POST "/linkedin/api/rest/posts" in turn:
      """
      [{"status": 201, "headers": {"x-restli-id": "urn:li:share:7"}}]
      """
    When social post 1 goes out on account 1
    Then the network heard these POST "/rest/posts" bodies:
      | content                                                                                                                                      |
      | {"multiImage": {"images": [{"id": "urn:li:image:1"}, {"id": "urn:li:image:2"}, {"id": "urn:li:image:3"}, {"id": "urn:li:image:4"}]}} |

  Scenario: A post with no photos sends no content and uploads nothing
    Given a social post due now to "linkedin" saying "one"
    And the network answers POST "/linkedin/api/rest/posts" in turn:
      """
      [{"status": 201, "headers": {"x-restli-id": "urn:li:share:7"}}]
      """
    When social post 1 goes out on account 1
    Then the network heard these POST "/rest/posts" bodies:
      | content |
      | absent  |
    And the network heard POST "/rest/images" 0 times

  Scenario: LinkedIn starting no upload keeps the error and posts nothing
    Given the photo "00000000000000000000000000000001.jpg" is 640 by 480
    And the media store holds "00000000000000000000000000000001.jpg"
    And a social post due now to "linkedin" saying "one"
    And part 1 of social post 1 shows:
      | key  | alt |
      | 00000000000000000000000000000001.jpg |     |
    And LinkedIn answers POST "/rest/images?action=initializeUpload" with:
      """
      {"value": {}}
      """
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "without an image and an upload URL"
    And the network heard POST "/rest/posts" 0 times

  Scenario: An upload that times out is tried again, since nothing is posted yet
    Given the photo "00000000000000000000000000000001.jpg" is 640 by 480
    And the media store holds "00000000000000000000000000000001.jpg"
    And a social post due now to "linkedin" saying "one"
    And part 1 of social post 1 shows:
      | key  | alt |
      | 00000000000000000000000000000001.jpg |     |
    And the network answers POST "/linkedin/api/rest/images?action=initializeUpload" in turn:
      """
      [{"body": {"value": {"image": "urn:li:image:1", "uploadUrl": "http://203.0.113.9/up/1"}}}]
      """
    And the network answers PUT "http://203.0.113.9/up/1" in turn:
      """
      [{"delay": 15000, "status": 201}]
      """
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "timed out"
    And the social_post_deliveries table has a row with:
      | failed |
      | false  |
    And the network heard POST "/rest/posts" 0 times
    And the delivery job fails so Sidekiq tries again
