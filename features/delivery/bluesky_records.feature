Feature: What a social post sends to Bluesky
  Bluesky gets each part as a feed record, signed in with the account's app password, with its links, tags and
  mentions marked as facets over byte ranges.

  Background:
    Given a Bluesky account "ada.example" is connected
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "cid", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc"}
      """

  Scenario: A post signs in and writes a feed record under a TID key
    Given a social post due now to "bluesky" saying "go 🎉 http://shares.localhost"
    When social post 1 goes out on account 1
    Then Bluesky heard the sign-in of "ada.example"
    And Bluesky record 1 holds:
      """
      {
        "collection": "app.bsky.feed.post",
        "repo": "did:plc:ada",
        "record": {
          "$type": "app.bsky.feed.post",
          "text": "go 🎉 http://shares.localhost",
          "facets": [
            {
              "features": [{"$type": "app.bsky.richtext.facet#link", "uri": "http://shares.localhost"}],
              "index": {"byteEnd": 31, "byteStart": 8}
            }
          ]
        }
      }
      """
    And Bluesky record 1 has no "reply"
    And Bluesky wrote 1 record, each under a TID key of its own
    And each Bluesky record is stamped with the time it was written
    And the network heard POST "/xrpc/com.atproto.repo.putRecord" with the header "Authorization" set to "Bearer jwt"

  Scenario: Each post goes under a key of its own
    Given a social post due now to "bluesky" saying "one"
    And a social post due now to "bluesky" saying "two"
    When social post 1 goes out on account 1
    And social post 2 goes out on account 1
    Then Bluesky wrote 2 records, each under a TID key of its own

  Scenario: An account connected since the last post signs in as itself
    Given a social post due now to "bluesky" saying "one"
    And a social post due now to "bluesky" saying "two"
    When social post 1 goes out on account 1
    Then Bluesky wrote 1 record, each under a TID key of its own
    Given a Bluesky account "two.example" is connected
    When social post 2 goes out on account 2
    Then Bluesky heard the sign-in of "two.example"

  Scenario Outline: Links and tags are marked over their bytes
    Given a social post due now to "bluesky" saying "<text>"
    When social post 1 goes out on account 1
    Then Bluesky record 1 holds:
      """
      {"record": {"facets": <facets>}}
      """

    Examples:
      | text                                                                    | facets                                                                                                                                                                                                                                                                                                       |
      | see (http://shares.localhost/Foo_(bar)).                                | [{"features": [{"uri": "http://shares.localhost/Foo_(bar)"}], "index": {"byteStart": 5, "byteEnd": 38}}]                                                                                                                                                                                                    |
      | see [http://shares.localhost/post].                                     | [{"features": [{"uri": "http://shares.localhost/post"}], "index": {"byteStart": 5, "byteEnd": 33}}]                                                                                                                                                                                                         |
      | read http://shares.localhost/post.                                      | [{"features": [{"uri": "http://shares.localhost/post"}], "index": {"byteStart": 5, "byteEnd": 33}}]                                                                                                                                                                                                         |
      | xhttps://no.example http://shares.localhost/a http://shares.localhost/x | [{"features": [{"uri": "http://shares.localhost/a"}]}, {"features": [{"uri": "http://shares.localhost/x"}]}]                                                                                                                                                                                                |
      | #hanami and #ruby                                                       | [{"features": [{"tag": "hanami"}], "index": {"byteStart": 0, "byteEnd": 7}}, {"features": [{"tag": "ruby"}], "index": {"byteStart": 12, "byteEnd": 17}}]                                                                                                                                                   |
      | go 🎉 café #ruby                                                         | [{"features": [{"tag": "ruby"}], "index": {"byteStart": 14, "byteEnd": 19}}]                                                                                                                                                                                                                                |
      | go #ruby　now                                                            | [{"features": [{"tag": "ruby"}], "index": {"byteStart": 4, "byteEnd": 9}}]                                                                                                                                                                                                                                  |
      | #ruby http://shares.localhost #hanami                                   | [{"features": [{"tag": "ruby"}], "index": {"byteStart": 0, "byteEnd": 5}}, {"features": [{"uri": "http://shares.localhost"}], "index": {"byteStart": 6, "byteEnd": 29}}, {"features": [{"tag": "hanami"}], "index": {"byteStart": 30, "byteEnd": 37}}]                                                       |
      | see http://shares.localhost/#top                                        | [{"features": [{"uri": "http://shares.localhost/#top"}], "index": {"byteStart": 4, "byteEnd": 32}}]                                                                                                                                                                                                         |
      | #see/http://shares.localhost                                            | [{"features": [{"uri": "http://shares.localhost"}], "index": {"byteStart": 5, "byteEnd": 28}}]                                                                                                                                                                                                              |
      | read #ruby.                                                             | [{"features": [{"tag": "ruby"}], "index": {"byteStart": 5, "byteEnd": 10}}]                                                                                                                                                                                                                                 |
      | #aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | [{"features": [{"tag": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}], "index": {"byteStart": 0, "byteEnd": 65}}] |

  Scenario Outline: Text with no link or tag gets no facets
    Given a social post due now to "bluesky" saying "<text>"
    When social post 1 goes out on account 1
    Then Bluesky record 1 has no "facets"

    Examples:
      | text          |
      | hello # world |
      | issue #123    |
      | #aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
      | C#sharp       |
