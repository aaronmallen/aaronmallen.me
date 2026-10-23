Feature: Sending a social post from the admin
  The composer queues a post to go out now or at a time I pick, saves a draft, or refuses a post it cannot send.

  Background:
    Given Mastodon and Bluesky are connected
    And I am signed in to the admin

  Scenario: Posting now queues the post, due right away, with its parts in order
    When I send the social composer:
      | accounts | mastodon         |
      | parts    | one // two // { *2} |
      | mode     | now              |
    Then the social toast says "Queued for Mastodon"
    And social post 1 is scheduled
    And social post 1 goes out within a minute
    And social post 1 goes to "mastodon"
    And social post 1 has the parts "one // two"

  Scenario: The composer says a post goes out within a minute
    When I visit "/admin/social"
    Then the social page shows "It goes out within a minute." in "[data-social-now].hint"
    When I choose "schedule" on the social page
    Then the social page shows "It goes out within a minute of the time you pick." in "[data-social-later].hint"

  Scenario: Posting now ignores the schedule time
    When I send the social composer:
      | accounts    | mastodon |
      | parts       | hello    |
      | mode        | now      |
      | schedule_at | soon     |
    Then social post 1 is scheduled

  Scenario: The targets follow the order the networks are listed in and the toast names them
    When I send the social composer:
      | accounts | bluesky,mastodon |
      | parts    | hello            |
    Then social post 1 goes to "mastodon,bluesky"
    And the social toast says "Queued for Mastodon + Bluesky"

  Scenario: A post goes only to the accounts left ticked
    Given my Mastodon account "ada" on "hachyderm.io" is connected
    When I send the social composer:
      | accounts | 3     |
      | parts    | hello |
      | mode     | now   |
    Then social post 1 goes to "mastodon"
    And social post 1 picked the accounts "3"

  Scenario: Scheduling makes the post due at the Chicago time I pick and says when
    When I send the social composer:
      | accounts    | mastodon         |
      | parts       | hello            |
      | mode        | schedule         |
      | schedule_at | 2027-03-01T09:30 |
    Then social post 1 is scheduled
    And social post 1 goes out at "2027-03-01T09:30" in Chicago
    And the social toast says "Scheduled for Mar 1, 2027 at 09:30"

  Scenario Outline: A schedule it cannot use is refused and nothing is queued
    When I send the social composer:
      | accounts    | mastodon       |
      | parts       | hello          |
      | mode        | <mode>         |
      | schedule_at | <schedule_at>  |
    Then the social page answered 422
    And the social composer says "<error>"
    And there are 0 social posts
    And the social page has a visible "[data-social-later].hint"

    Examples:
      | mode     | schedule_at      | error                 |
      | schedule | soon             | Enter a date and time |
      | schedule | 2027-03-14T02:30 | the clocks skip it    |

  Scenario: A mode it does not know is refused
    When I send the social composer:
      | accounts | mastodon |
      | parts    | hello    |
      | mode     | later    |
    Then the social page answered 422
    And there are 0 social posts

  Scenario Outline: Saving a draft keeps the text, even over a limit or for an intent it does not know
    When I send the social composer:
      | accounts | mastodon   |
      | parts    | <parts>    |
      | intent   | <intent>   |
    Then social post 1 is draft
    And social post 1 has the parts "<stored>"
    And the social toast says "Draft saved"

    Examples:
      | intent | parts                                | stored                         |
      | draft  | hello                                | hello                          |
      | draft  | {a*501}                              | {a*501}                        |
      | launch | hello                                | hello                          |
      | draft  | one\r\ntwo // three\rfour            | one\ntwo // three\nfour        |

  Scenario: An empty post is refused with one empty part kept
    When I send the social composer:
      | accounts | bluesky |
      | parts    |         |
    Then the social page answered 422
    And the social composer says "Write something first"
    And the social composer holds ""
    And the social account targets are "1,2"
    And the picked social accounts are "bluesky"
    And the social page has no "[data-social-restore]"

  Scenario: A post with only blank parts is refused
    When I send the social composer:
      | accounts | mastodon |
      | parts    | {   *1}  |
    Then the social page answered 422
    And the social composer says "Write something first"

  Scenario: A post with no network is refused
    When I send the social composer:
      | accounts |       |
      | parts    | hello |
    Then the social composer says "Pick a network"
    And there are 0 social posts

  Scenario Outline: A part over a picked network's limit is refused and the text is kept
    Given the people table holds:
      | key | name         | mastodon_handle  | bluesky_handle           | bluesky_did |
      | ada | Ada Lovelace | @ada@ruby.social | ada-lovelace.bsky.social | did:plc:ada |
    When I send the social composer:
      | accounts | <accounts> |
      | parts    | <text>     |
    Then the social page answered 422
    And the social composer says "over the limit"
    And the social composer holds "<text>"
    And there are 0 social posts

    Examples:
      | accounts         | text                          |
      | mastodon         | {a*501}                       |
      | mastodon,bluesky | {a*301}                       |
      | bluesky          | @{ada} {a*280}                |
      | bluesky          | {a*262} {site}/writing/hello  |
      | mastodon,bluesky | hi // {a*301}                 |
      | bluesky          | {a*285} @{ada}                |

  Scenario: A part over the byte limit is marked over in the meter
    When I send the social composer:
      | accounts | bluesky          |
      | parts    | {👨‍👩‍👧‍👦*121}       |
    Then the social page answered 422
    And the Bluesky social counter is over

  Scenario Outline: A part under every picked limit is queued
    Given the people table holds:
      | key | name         | mastodon_handle  | bluesky_handle           | bluesky_did |
      | ada | Ada Lovelace | @ada@ruby.social | ada-lovelace.bsky.social | did:plc:ada |
    When I send the social composer:
      | accounts | <accounts> |
      | parts    | <text>     |
    Then social post 1 is scheduled

    Examples:
      | accounts | text                         |
      | mastodon | {a*301}                      |
      | mastodon | {a*400}                      |
      | bluesky  | @{ada} {a*274}               |
      | bluesky  | {a*251} {site}/writing/hello |

  Scenario Outline: A mention must name someone in the directory
    Given the people table holds:
      | key          | name         |
      | ada-lovelace | Ada Lovelace |
      | gone         | Gone Person  |
    And person "gone" was taken out of the directory
    When I send the social composer:
      | accounts | mastodon |
      | parts    | <text>   |
    Then there are <count> social posts

    Examples:
      | text                | count |
      | hi @{ada-lovelace}  | 1     |
      | hi @{nobody}        | 0     |
      | hi @{gone}          | 0     |

  Scenario: A mention of nobody says why
    When I send the social composer:
      | accounts | mastodon     |
      | parts    | hi @{nobody} |
    Then the social composer says "names nobody in the directory"

  Scenario: A mention typed by hand is kept as typed
    Given the people table holds:
      | key          | name         |
      | ada-lovelace | Ada Lovelace |
    When I send the social composer:
      | accounts | mastodon           |
      | parts    | hi @{ada-lovelace} |
      | mode     | now                |
    Then social post 1 has the parts "hi @{ada-lovelace}"

  Scenario: An item opens in the composer with its text, counts and its own address
    Given the social posts:
      | text  | status |
      | first | draft  |
    When I open social post 1 in the composer
    Then the social composer holds "first"
    And the social composer counts "Mastodon 5/500, Bluesky 5/300, LinkedIn 5/3000"
    And the social page has 1 "[data-social-composer][action='/admin/social/1']"
    And the page has no axe breaches in light or dark

  Scenario: A queued item opens with its send time
    Given the social posts:
      | text  | status    | at                        |
      | later | scheduled | 2027-03-01T09:30:00-06:00 |
    When I open social post 1 in the composer
    Then the "#social-schedule_at" on the social page has "value" set to "2027-03-01T09:30"

  Scenario Outline: The composer opens no item for a posted one, one mid-delivery, or a bad ID
    Given the social posts:
      | text | status   | at         |
      | gone | <status> | 1 hour ago |
    And the social_post_deliveries table holds:
      | social_post_id | network  | error        |
      | <delivered>    | mastodon | rate limited |
    When I open the social page at "?edit=<edit>"
    Then the social composer holds ""

    Examples:
      | status    | delivered | edit |
      | posted    | 1         | 1    |
      | scheduled | 1         | 1    |
      | scheduled | 1         | 1abc |

  Scenario: Saving an item writes back to it and adds no second item
    Given the social posts:
      | text  | status |
      | first | draft  |
    When I send the social composer:
      | to       | /admin/social/1 |
      | accounts | mastodon        |
      | parts    | second          |
      | mode     | now             |
    Then social post 1 has the parts "second"
    And there are 1 social posts

  Scenario: A draft stays a draft for an intent it does not know
    Given the social posts:
      | text  | status |
      | first | draft  |
    When I send the social composer:
      | to       | /admin/social/1 |
      | accounts | mastodon        |
      | parts    | second          |
      | intent   | sendit          |
    Then social post 1 is draft

  Scenario: A refused save keeps the item open and says why
    Given the social posts:
      | text  | status |
      | first | draft  |
    When I send the social composer:
      | to       | /admin/social/1 |
      | accounts | mastodon        |
      | parts    | {a*501}         |
    Then the social page has 1 "[data-social-composer][action='/admin/social/1']"
    And the social composer says "over the limit"

  Scenario: A save of a posted item changes nothing and goes back to the queue
    Given the social posts:
      | text | status | at                   |
      | gone | posted | 2026-09-13T02:30:00Z |
    When I send the social composer:
      | to       | /admin/social/1 |
      | accounts | mastodon        |
      | parts    | new             |
    Then I am on "/admin/social"
    And the social toast says "Already posted · nothing was saved"
    And social post 1 is posted
    And social post 1 has the parts "gone"

  Scenario: A save of an item that is not there or was removed before the save answers 404
    Given the social posts:
      | text  | status |
      | first | draft  |
    When I remove social post 1 from the drafts queue
    And I send the social composer:
      | to       | /admin/social/1 |
      | accounts | mastodon        |
      | parts    | new             |
    Then the social page answered 404
    When I send the social composer:
      | to       | /admin/social/2 |
      | accounts | mastodon        |
      | parts    | new             |
    Then the social page answered 404

  Scenario Outline: An item mid-delivery keeps its text and time on any save
    Given the social posts:
      | text  | status    | at  |
      | first | scheduled | now |
    And the social_post_deliveries table holds:
      | social_post_id | network  | error        |
      | 1              | mastodon | rate limited |
    When I send the social composer:
      | to          | /admin/social/1 |
      | accounts    | mastodon        |
      | parts       | second          |
      | intent      | <intent>        |
      | mode        | <mode>          |
      | schedule_at | <schedule_at>   |
    Then the social toast says "Already posted · nothing was saved"
    And social post 1 is scheduled
    And social post 1 goes out within a minute
    And social post 1 has the parts "first"

    Examples:
      | intent | mode     | schedule_at      |
      | send   | now      |                  |
      | send   | schedule | 2027-03-01T09:30 |
      | draft  | now      |                  |

  Scenario: A LinkedIn thread whose joined text runs over LinkedIn's limit is refused
    Given my LinkedIn account "Ada Lovelace" is connected
    When I send the social composer:
      | accounts | linkedin            |
      | parts    | {a*1500} // {b*1499} |
    Then the social composer says "over the limit"
    And 2 LinkedIn social counters are over
    And the social page shows "LinkedIn 3001/3000" in ".compose-count.over"
