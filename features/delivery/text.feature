Feature: The text each network gets
  At send time a social post's mentions turn into each network's handle, links to the site get the network's ref
  tag, and links elsewhere go out as short links. The stored post keeps what I wrote.

  Background:
    Given a Mastodon account on "ruby.social" is connected
    And a Bluesky account "ada.example" is connected
    And the people table holds:
      | key   | name         | mastodon_handle  | bluesky_handle  | bluesky_did          |
      | ada   | Ada Lovelace | @ada@ruby.social | ada.bsky.social | did:plc:ada-lovelace |
      | grace | Grace Hopper | null             | null            | null                 |
    And Mastodon answers POST "/ruby.social/api/v1/statuses" with:
      """
      {"id": "1", "url": "https://ruby.social/@ada/1"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "cid", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc"}
      """
    And the web answers GET "http://203.0.113.5/ada" with:
      """
      <title>Ada</title>
      """

  Scenario Outline: Mastodon gets each person's Mastodon handle or name
    Given a social post due now to "mastodon" saying "<written>"
    When social post 1 goes out on account 1
    Then the network heard these POST "/ruby.social/api/v1/statuses" bodies:
      | status |
      | <sent> |

    Examples:
      | written          | sent                 |
      | hi @{ada}!       | hi @ada@ruby.social! |
      | thanks @{grace}  | thanks Grace Hopper  |
      | hi @{}           | hi @{}               |

  Scenario: A handle changed after the post was queued goes out in its new form
    Given a social post due now to "mastodon" saying "hi @{ada}"
    And person "ada" now has the Mastodon handle "@ada@hachyderm.io"
    When social post 1 goes out on account 1
    Then the network heard these POST "/ruby.social/api/v1/statuses" bodies:
      | status               |
      | hi @ada@hachyderm.io |

  Scenario: Someone taken out of the directory goes out as their key
    Given a social post due now to "mastodon" saying "hi @{ada}"
    And person "ada" is gone
    When social post 1 goes out on account 1
    Then the network heard these POST "/ruby.social/api/v1/statuses" bodies:
      | status |
      | hi ada |

  Scenario: Bluesky gets the Bluesky handle marked with the stored DID
    Given a social post due now to "bluesky" saying "🎉 @{ada}!"
    When social post 1 goes out on account 2
    Then Bluesky record 1 holds:
      """
      {
        "record": {
          "text": "🎉 @ada.bsky.social!",
          "facets": [
            {
              "features": [{"$type": "app.bsky.richtext.facet#mention", "did": "did:plc:ada-lovelace"}],
              "index": {"byteStart": 5, "byteEnd": 21}
            }
          ]
        }
      }
      """

  Scenario: Mention, tag and link facets stay apart and in order
    Given a social post due now to "bluesky" saying "@{ada} #ruby http://shares.localhost"
    When social post 1 goes out on account 2
    Then Bluesky record 1 holds:
      """
      {
        "record": {
          "facets": [
            {"features": [{"did": "did:plc:ada-lovelace"}], "index": {"byteStart": 0, "byteEnd": 16}},
            {"features": [{"tag": "ruby"}], "index": {"byteStart": 17, "byteEnd": 22}},
            {"features": [{"uri": "http://shares.localhost"}], "index": {"byteStart": 23, "byteEnd": 46}}
          ]
        }
      }
      """

  Scenario: No facet overlaps a mention
    Given a social post due now to "bluesky" saying "http://shares.localhost/@{ada}"
    When social post 1 goes out on account 2
    Then Bluesky record 1 holds:
      """
      {"record": {"facets": [{"features": [{"did": "did:plc:ada-lovelace"}], "index": {"byteStart": 24, "byteEnd": 40}}]}}
      """

  Scenario: Someone with no Bluesky handle goes out as their name with no facet
    Given a social post due now to "bluesky" saying "thanks @{grace}"
    When social post 1 goes out on account 2
    Then Bluesky record 1 holds:
      """
      {"record": {"text": "thanks Grace Hopper"}}
      """
    And Bluesky record 1 has no "facets"

  Scenario: Each network gets its own tag on a link to the site
    Given a social post due now to "mastodon bluesky" saying "read {site}/writing/hello."
    When social post 1 goes out on account 1
    And social post 1 goes out on account 2
    Then the network heard these POST "/ruby.social/api/v1/statuses" bodies:
      | status                                    |
      | read {site}/writing/hello?ref=mastodon.   |
    And Bluesky record 1 holds:
      """
      {"record": {"text": "read {site}/writing/hello?ref=bluesky."}}
      """
    And Bluesky record 1 marks "{site}/writing/hello?ref=bluesky" as a link facet
    And social post 1 reads "read {site}/writing/hello."

  Scenario Outline: A link to the site takes its tag where it fits
    Given a social post due now to "mastodon" saying "see <written>"
    When social post 1 goes out on account 1
    Then the network heard these POST "/ruby.social/api/v1/statuses" bodies:
      | status     |
      | see <sent> |

    Examples:
      | written                      | sent                                     |
      | {site}                       | {site}/?ref=mastodon                     |
      | {site}/writing?page=2        | {site}/writing?page=2&ref=mastodon       |
      | {site}/writing/hello#end     | {site}/writing/hello?ref=mastodon#end    |
      | {site}/writing/hello?ref=talk | {site}/writing/hello?ref=talk           |

  Scenario: A mention after a tagged link is marked over the right bytes
    Given a social post due now to "bluesky" saying "{site}/writing/hello @{ada}"
    When social post 1 goes out on account 2
    Then Bluesky record 1 marks "@ada.bsky.social" as a mention facet
    And Bluesky record 1 marks "{site}/writing/hello?ref=bluesky" as a link facet

  Scenario: A link to another site goes out as its short link, and its slow page holds nothing up
    Given a social post due now to "mastodon" saying "see http://203.0.113.5/ada and {site}/writing/hello"
    And the network answers GET "http://203.0.113.5/ada" in turn:
      """
      [{"delay": 8000, "body": "<title>Ada</title>"}]
      """
    When social post 1 goes out on account 1
    Then the network heard these POST "/ruby.social/api/v1/statuses" bodies:
      | status                                                                  |
      | see http://shares.localhost/1 and {site}/writing/hello?ref=mastodon |
    And the short_codes table has a row with:
      | id | code |
      | 1  | 1    |
    And the social_post_deliveries table has a row with:
      | remote_ids |
      | {1}        |

  Scenario: A link already on the short host goes out as typed
    Given a social post due now to "mastodon" saying "see http://shares.localhost/talk"
    When social post 1 goes out on account 1
    Then the network heard these POST "/ruby.social/api/v1/statuses" bodies:
      | status                           |
      | see http://shares.localhost/talk |
    And the short_links table holds 0 rows

  Scenario: A link I shortened before goes out at its own code
    Given the short_codes table holds:
      | code       |
      | github-ada |
    And the short_links table holds:
      | short_code_id | destination            |
      | 1             | http://203.0.113.5/ada |
    And a social post due now to "mastodon" saying "see http://203.0.113.5/ada"
    When social post 1 goes out on account 1
    Then the network heard these POST "/ruby.social/api/v1/statuses" bodies:
      | status                                 |
      | see http://shares.localhost/github-ada |
    And the short_links table holds 1 rows

  Scenario: Each network gets the same new short link
    Given a social post due now to "mastodon bluesky" saying "see http://203.0.113.5/ada"
    When social post 1 goes out on account 1
    And social post 1 goes out on account 2
    Then the network heard these POST "/ruby.social/api/v1/statuses" bodies:
      | status                        |
      | see http://shares.localhost/1 |
    And Bluesky record 1 holds:
      """
      {"record": {"text": "see http://shares.localhost/1"}}
      """
    And Bluesky record 1 marks "http://shares.localhost/1" as a link facet
    And the short_links table has a row with:
      | destination            | title |
      | http://203.0.113.5/ada | Ada   |
    And the short_links table holds 1 rows
    And social post 1 reads "see http://203.0.113.5/ada"

  Scenario: A thread's parts each go out with their links and mentions expanded, in order
    Given a social post due now to "mastodon" in parts:
      | hi @{ada}                  |
      | see http://203.0.113.5/ada |
    And the network answers POST "/mastodon/ruby.social/api/v1/statuses" in turn:
      """
      [{"body": {"id": "1", "url": "https://ruby.social/@ada/1"}}, {"body": {"id": "2", "url": "https://ruby.social/@ada/2"}}]
      """
    When social post 1 goes out on account 1
    Then the network heard these POST "/ruby.social/api/v1/statuses" bodies:
      | status                        |
      | hi @ada@ruby.social           |
      | see http://shares.localhost/1 |

  Scenario: A mention after a link that went short is marked over the right bytes
    Given a social post due now to "bluesky" saying "see http://203.0.113.5/ada @{ada}"
    When social post 1 goes out on account 2
    Then Bluesky record 1 holds:
      """
      {"record": {"text": "see http://shares.localhost/1 @ada.bsky.social"}}
      """
    And Bluesky record 1 marks "@ada.bsky.social" as a mention facet
    And Bluesky record 1 marks "http://shares.localhost/1" as a link facet
