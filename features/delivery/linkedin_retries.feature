Feature: LinkedIn retries that look before they post
  With leave to read the member's posts, a send that may have gone out checks the recent posts for its text before
  it posts again.

  Background:
    Given a LinkedIn account is connected with leave to read the member's posts

  Scenario: A timeout with leave to read the member's posts is tried again
    Given a social post due now to "linkedin" in parts:
      | one |
      | two |
    And the network answers POST "/linkedin/api/rest/posts" in turn:
      """
      [{"delay": 15000, "status": 201}]
      """
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "timed out"
    And the social_post_deliveries table has a row with:
      | failed |
      | false  |
    And the delivery job fails so Sidekiq tries again

  Scenario Outline: A retry finds the post already out and posts nothing more
    Given a social post due now to "linkedin" saying "<written>"
    And the network answers POST "/linkedin/api/rest/posts" in turn:
      """
      [{"delay": 15000, "status": 201}]
      """
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "timed out"
    Given LinkedIn answers GET "/rest/posts" with:
      """
      {"elements": <recent>}
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | remote_ids | error |
      | {<found>}  | null  |
    And the network heard POST "/rest/posts" 1 time

    Examples:
      | written    | recent                                                                                                 | found          |
      | one\n\ntwo | [{"id": "urn:li:share:0", "commentary": "other"}, {"id": "urn:li:share:1", "commentary": "one\\n\\ntwo"}] | urn:li:share:1 |
      | (a) #ruby  | [{"id": "urn:li:share:0", "commentary": "\\\\(a\\\\) {hashtag\|\\\\#\|ruby}"}]                                 | urn:li:share:0 |

  Scenario: A retry posts when no recent post holds the text
    Given a social post due now to "linkedin" saying "hello"
    And the network answers POST "/linkedin/api/rest/posts" in turn:
      """
      [{"delay": 15000, "status": 201}, {"status": 201, "headers": {"x-restli-id": "urn:li:share:9"}}]
      """
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "timed out"
    Given LinkedIn answers GET "/rest/posts" with:
      """
      {"elements": [{"id": "urn:li:share:0", "commentary": "other"}]}
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | remote_ids       |
      | {urn:li:share:9} |
  Scenario: A claimed send that failed checks recent posts before it posts again
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
      [{"status": 500}, {"status": 201, "headers": {"x-restli-id": "urn:li:share:9"}}]
      """
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "500"
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | remote_ids       |
      | {urn:li:share:0} |
    And the network heard POST "/rest/posts" 1 time

  Scenario: A retry that finds the post already out uploads no photo again
    Given the photo "00000000000000000000000000000001.jpg" is 640 by 480
    And the media store holds "00000000000000000000000000000001.jpg"
    And a social post due now to "linkedin" saying "one"
    And part 1 of social post 1 shows:
      | key                                  | alt |
      | 00000000000000000000000000000001.jpg |     |
    And the network answers POST "/linkedin/api/rest/images?action=initializeUpload" in turn:
      """
      [{"body": {"value": {"image": "urn:li:image:1", "uploadUrl": "http://203.0.113.9/up/1"}}}]
      """
    And the web answers PUT "http://203.0.113.9/up/1" with status 201
    And the network answers POST "/linkedin/api/rest/posts" in turn:
      """
      [{"delay": 15000, "status": 201}]
      """
    When social post 1 goes out on account 1
    Then the delivery error on account 1 holds "timed out"
    Given LinkedIn answers GET "/rest/posts" with:
      """
      {"elements": [{"id": "urn:li:share:0", "commentary": "one"}]}
      """
    When social post 1 goes out on account 1
    Then the social_post_deliveries table has a row with:
      | remote_ids       |
      | {urn:li:share:0} |
    And the network heard POST "/rest/images" 1 time
