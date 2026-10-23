Feature: Suggested edits on a social post
  An agent suggests edits to the parts of an unsent social post, and the owner accepts or rejects them in the queue.

  Background:
    Given I am signed in to the admin

  Scenario: The queue counts the open edits on each item
    Given a draft social post to "mastodon" that reads "teh cat sat"
    And a scheduled social post to "mastodon" that reads "teh cat sat"
    And a draft social post to "mastodon" that reads "teh dog ran"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
      | sat      | slept       | 1    |
    And the suggested edits for social post 2:
      | original | replacement | part |
      | teh      | the         | 1    |
    When I visit "/admin/social?filter=drafts"
    Then the social queue item counts "2 suggestions"
    And the page has no axe breaches in light or dark
    When I visit "/admin/social"
    Then the social queue item counts "1 suggestion"

  Scenario: The queue shows no count once every edit is settled or on an item with none
    Given a draft social post to "mastodon" that reads "teh cat sat"
    And a draft social post to "mastodon" that reads "teh dog ran"
    And the suggested edits for social post 1:
      | original | replacement | part | status   |
      | teh      | the         | 1    | rejected |
    When I visit "/admin/social?filter=drafts"
    Then the social queue item counts no suggestions

  Scenario: The queue counts only the newest set of edits
    Given a draft social post to "mastodon" that reads "teh cat sat"
    And an API token
    When I POST "/suggestions" through the API with:
      """
      {"target": "social_post", "id": 1, "edits": [
        {"original": "teh", "replacement": "the", "reason": "typo", "part": 1},
        {"original": "sat", "replacement": "slept", "reason": "typo", "part": 1}
      ]}
      """
    And I POST "/suggestions" through the API with:
      """
      {"target": "social_post", "id": 1, "edits": [{"original": "teh", "replacement": "the", "reason": "typo", "part": 1}]}
      """
    And I visit "/admin/social?filter=drafts"
    Then the social queue item counts "1 suggestion"

  Scenario: The card lists each open edit above the composer
    Given a draft social post to "mastodon" with the parts:
      | teh cat sat |
      | teh dog ran |
    And the suggested edits for social post 1:
      | original | replacement | part | reason |
      | teh      | the         | 2    | typo   |
      | sat      | slept       | 1    | tense  |
    When I visit "/admin/social"
    Then no social suggestions card shows
    When I visit "/admin/social?edit=1"
    Then the social suggestions card shows
    And the social suggestions card sits above the composer
    And the social suggestions name the parts "Part 1, Part 2"
    And the suggestions read:
      | before | after | reason |
      | sat    | slept | tense  |
      | teh    | the   | typo   |
    And the suggested edits offer "Accept Reject Accept Reject"
    And the suggestions offer "Accept all, Reject all" for every edit
    And the page has no axe breaches in light or dark

  Scenario: The card names no part on a single part item and shows nothing with no edits
    Given a draft social post to "mastodon" that reads "teh cat sat"
    And a draft social post to "mastodon" that reads "teh dog ran"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
    When I visit "/admin/social?edit=1"
    Then the social suggestions name no part
    When I visit "/admin/social?edit=2"
    Then no social suggestions card shows

  Scenario: Accept and Reject in the card decide one edit each
    Given a draft social post to "mastodon" that reads "teh cat sat"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
      | sat      | slept       | 1    |
    When I visit "/admin/social?edit=1"
    And I press "Accept" on the first suggestion
    Then the suggestion toast says "Suggestion applied"
    And the suggestions read:
      | before | after |
      | sat    | slept |
    When I press "Reject" on the first suggestion
    Then the suggestion toast says "Suggestion rejected"
    And social post 1 has the parts:
      | the cat sat |
    And the edits on social post 1 stand as "accepted rejected"

  Scenario: Accept all in the card applies every edit across every part
    Given a draft social post to "mastodon" with the parts:
      | teh cat sat |
      | teh dog ran |
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
      | teh      | the         | 2    |
    When I visit "/admin/social?edit=1"
    And I press "Accept all" for every suggestion
    Then the suggestion toast says "2 suggestions applied"
    And social post 1 has the parts:
      | the cat sat |
      | the dog ran |

  Scenario: Reject all in the card rejects every edit
    Given a draft social post to "mastodon" that reads "teh cat sat"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
      | sat      | slept       | 1    |
    When I visit "/admin/social?edit=1"
    And I press "Reject all" for every suggestion
    Then the suggestion toast says "2 suggestions rejected"
    And the edits on social post 1 stand as "rejected rejected"
    And social post 1 has the parts:
      | teh cat sat |

  Scenario: Accepting one edit applies it to its own part only
    Given a draft social post to "mastodon" with the parts:
      | teh cat sat |
      | teh dog ran |
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 2    |
      | teh      | the         | 1    |
    When I accept suggested edit "1" on social post 1
    Then social post 1 has the parts:
      | teh cat sat |
      | the dog ran |
    And the edits on social post 1 stand as "accepted pending"

  Scenario: A decision returns to the item in the queue
    Given a draft social post to "mastodon" that reads "teh cat sat"
    And a draft social post to "mastodon" that reads "teh dog ran"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
    And the suggested edits for social post 2:
      | original | replacement | part |
      | teh      | the         | 1    |
    When I accept every suggested edit on social post 1
    Then the suggestion decision sends me to "/admin/social?filter=queued&edit=1"
    When I accept every suggested edit on social post 2 from the "drafts" filter
    Then the suggestion decision sends me to "/admin/social?filter=drafts&edit=2"

  Scenario: An edit whose text has gone is marked stale and can be dismissed
    Given a draft social post to "mastodon" that reads "the cat sat"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
    When I visit "/admin/social?edit=1"
    Then the suggested edit is marked "stale"
    And the suggested edits offer "Dismiss"
    When I accept suggested edit "1" on social post 1
    Then the edits on social post 1 stand as "stale"
    And social post 1 has the parts:
      | the cat sat |
    When I follow the suggestion decision
    Then the suggestion toast says "Nothing applied · every edit went stale"
    When I reject suggested edit "1" on social post 1
    Then the edits on social post 1 stand as "rejected"

  Scenario Outline: An edit whose text appears twice or not at all goes stale
    Given a draft social post to "mastodon" that reads "<part>"
    And the suggested edits for social post 1:
      | original   | replacement | part |
      | <original> | cat         | 1    |
    When I accept every suggested edit on social post 1
    Then the edits on social post 1 stand as "stale"
    And social post 1 has the parts:
      | <part> |
    When I follow the suggestion decision
    Then the suggestion toast says "Nothing applied · every edit went stale"

    Examples:
      | part                | original |
      | teh cat and teh dog | teh      |
      | teh cat sat         | dog      |

  Scenario: An edit already marked stale stays stale until dismissed
    Given a draft social post to "mastodon" that reads "teh cat sat"
    And the suggested edits for social post 1:
      | original | replacement | part | status |
      | teh      | the         | 1    | stale  |
    When I accept every suggested edit on social post 1
    Then the edits on social post 1 stand as "stale"
    And social post 1 has the parts:
      | teh cat sat |
    When I follow the suggestion decision
    Then the suggestion toast says "Nothing applied · every edit went stale"
    When I accept suggested edit "1" on social post 1
    And I follow the suggestion decision
    Then the suggestion toast says "Nothing applied · every edit went stale"
    When I reject every suggested edit on social post 1
    Then the edits on social post 1 stand as "rejected"
    When I follow the suggestion decision
    Then no social suggestions card shows

  Scenario: Rejecting leaves the parts alone
    Given a draft social post to "mastodon" that reads "teh cat sat"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
      | sat      | slept       | 1    |
    When I reject suggested edit "1" on social post 1
    Then the edits on social post 1 stand as "rejected pending"
    And social post 1 has the parts:
      | teh cat sat |
    When I follow the suggestion decision
    Then the suggestion toast says "Suggestion rejected"
    When I reject every suggested edit on social post 1
    Then the edits on social post 1 stand as "rejected rejected"
    When I follow the suggestion decision
    Then the suggestion toast says "Suggestion rejected"

  Scenario: Rejecting every edit counts them
    Given a draft social post to "mastodon" that reads "teh cat sat"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
      | sat      | slept       | 1    |
    When I reject every suggested edit on social post 1
    And I follow the suggestion decision
    Then the suggestion toast says "2 suggestions rejected"

  Scenario: An edit that would pass Mastodon's limit is held back
    Given a draft social post to "mastodon" that reads "teh cat {a*492}"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | their       | 1    |
      | cat      | dog         | 1    |
    When I visit "/admin/social?edit=1"
    Then the suggested edit is marked "Over the Mastodon limit of 500"
    When I accept suggested edit "1" on social post 1
    Then social post 1 has the parts:
      | teh cat {a*492} |
    And the edits on social post 1 stand as "pending pending"
    When I follow the suggestion decision
    Then the suggestion toast says "Not applied · part 1 would pass the Mastodon limit of 500"
    When I accept every suggested edit on social post 1
    Then social post 1 has the parts:
      | teh dog {a*492} |
    When I reject suggested edit "1" on social post 1
    Then the edits on social post 1 stand as "rejected accepted"

  Scenario: An over the limit edit offers only Reject
    Given a draft social post to "mastodon" that reads "teh cat {a*492}"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | their       | 1    |
    When I visit "/admin/social?edit=1"
    Then the suggested edits offer "Reject"

  Scenario: The limit of a network the item does not target does not count
    Given a draft social post to "mastodon" that reads "teh {a*295}"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | their       | 1    |
    When I accept suggested edit "1" on social post 1
    Then social post 1 has the parts:
      | their {a*295} |

  Scenario: An edit that would pass Bluesky's limit once a mention expands is held back
    Given a person "ada" on Bluesky as "ada-lovelace.bsky.social"
    And a draft social post to "bluesky" that reads "teh @{ada} {a*270}"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | their       | 1    |
    When I visit "/admin/social?edit=1"
    Then the suggested edit is marked "Over the Bluesky limit of 300"
    When I accept suggested edit "1" on social post 1
    Then social post 1 has the parts:
      | teh @{ada} {a*270} |
    And the edits on social post 1 stand as "pending"

  Scenario: An edit that would pass Bluesky's limit once its link to the site is tagged is held back
    Given a draft social post to "bluesky" that reads "teh {a*247} {site}/writing/hello"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | their       | 1    |
    When I visit "/admin/social?edit=1"
    Then the suggested edit is marked "Over the Bluesky limit of 300"
    When I accept suggested edit "1" on social post 1
    Then social post 1 has the parts:
      | teh {a*247} {site}/writing/hello |
    And the edits on social post 1 stand as "pending"
    When I follow the suggestion decision
    Then the suggestion toast says "Not applied · part 1 would pass the Bluesky limit of 300"

  Scenario: An edit that would pass LinkedIn's limit once the thread joins is held back
    Given a draft social post to "linkedin" with the parts:
      | teh {a*1496} |
      | {b*1498}     |
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | their       | 1    |
    When I visit "/admin/social?edit=1"
    Then the suggested edit is marked "Over the LinkedIn limit of 3000"
    When I accept every suggested edit on social post 1
    Then social post 1 has the parts:
      | teh {a*1496} |
      | {b*1498}     |
    And the edits on social post 1 stand as "pending"
    When I follow the suggestion decision
    Then the suggestion toast says "Not applied · part 1 would pass the LinkedIn limit of 3000"

  Scenario: An edit that keeps LinkedIn's joined thread in the limit applies
    Given a draft social post to "linkedin" with the parts:
      | teh {a*1496} |
      | {b*1498}     |
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
    When I accept every suggested edit on social post 1
    Then social post 1 has the parts:
      | the {a*1496} |
      | {b*1498}     |

  Scenario: An edit to one part applies though another part is over the limit
    Given a draft social post to "bluesky" with the parts:
      | teh cat  |
      | {b*301}  |
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
    When I accept suggested edit "1" on social post 1
    Then social post 1 has the parts:
      | the cat |
      | {b*301} |
    And the edits on social post 1 stand as "accepted"
    When I follow the suggestion decision
    Then the suggestion toast says "Suggestion applied"

  Scenario Outline: Edits that would leave a part empty change nothing
    Given a draft social post to "mastodon" with the parts:
      | teh cat sat |
      | teh         |
    And the suggested edits for social post 1:
      | original | replacement   | part |
      | teh      | the           | 1    |
      | teh      | <replacement> | 2    |
    When I accept every suggested edit on social post 1
    Then social post 1 has the parts:
      | teh cat sat |
      | teh         |
    And the edits on social post 1 stand as "pending pending"
    When I follow the suggestion decision
    Then the suggestion toast says "Not applied · part 2 would be left empty"

    Examples:
      | replacement      |
      |                  |
      | {em space}{nbsp} |

  Scenario: An item already posted takes no decision
    Given a posted social post to "mastodon" that reads "teh cat sat"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
    When I visit "/admin/social?filter=posted"
    Then the social queue item counts no suggestions
    When I visit "/admin/social?edit=1"
    Then no social suggestions card shows
    When I accept every suggested edit on social post 1
    Then the suggestion decision answers 404
    When I reject every suggested edit on social post 1
    Then the suggestion decision answers 404

  Scenario: An item already posted with every edit settled still refuses a reject
    Given a posted social post to "mastodon" that reads "teh cat sat"
    And the suggested edits for social post 1:
      | original | replacement | part | status   |
      | teh      | the         | 1    | rejected |
    When I reject every suggested edit on social post 1
    Then the suggestion decision answers 404

  Scenario: An item mid-delivery says it has gone out
    Given a due social post to "mastodon" that reads "teh cat sat"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
    And the social_post_deliveries table holds:
      | social_post_id | network  | error        |
      | 1              | mastodon | rate limited |
    When I accept every suggested edit on social post 1
    Then social post 1 has the parts:
      | teh cat sat |
    And the edits on social post 1 stand as "pending"
    When I follow the suggestion decision
    Then the suggestion toast says "Already posted · nothing was applied"

  Scenario: A decision on an item with no suggestions answers 404
    Given a draft social post to "mastodon" that reads "teh cat sat"
    When I accept every suggested edit on social post 1
    Then the suggestion decision answers 404
    When I reject every suggested edit on social post 0
    Then the suggestion decision answers 404

  Scenario: Rejecting twice says nothing was left to reject
    Given a draft social post to "mastodon" that reads "teh cat sat"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
    When I reject every suggested edit on social post 1
    And I reject every suggested edit on social post 1
    And I follow the suggestion decision
    Then the suggestion toast says "Nothing to reject"

  Scenario: A decision ignores an edit from another item
    Given a draft social post to "mastodon" that reads "teh cat sat"
    And a draft social post to "mastodon" that reads "teh dog ran"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
    And the suggested edits for social post 2:
      | original | replacement | part |
      | teh      | the         | 1    |
    When I reject suggested edit "2" on social post 1
    Then the edits on social post 1 stand as "pending"
    And the edits on social post 2 stand as "pending"
    When I accept suggested edit "2" on social post 1
    And I follow the suggestion decision
    Then no suggestion toast shows
    And the edits on social post 1 stand as "pending"

  Scenario Outline: A decision with an edit ID that has text after it decides nothing
    Given a draft social post to "mastodon" that reads "teh cat sat"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
    When I <decision> suggested edit "1abc" on social post 1
    Then the edits on social post 1 stand as "pending"
    And social post 1 has the parts:
      | teh cat sat |

    Examples:
      | decision |
      | accept   |
      | reject   |

  Scenario: A decision without a CSRF token is turned away
    Given a draft social post to "mastodon" that reads "teh cat sat"
    And the suggested edits for social post 1:
      | original | replacement | part |
      | teh      | the         | 1    |
    When I send the suggestion form to "/admin/social/1/suggestions/accept" without a CSRF token
    Then the suggestion decision answers 403
    And the edits on social post 1 stand as "pending"

  Scenario Outline: A visitor who is not signed in cannot decide on a social post's edits
    When a visitor sends a suggestion decision to "/admin/social/1/suggestions/<decision>"
    Then the suggestion decision answers 403

    Examples:
      | decision |
      | accept   |
      | reject   |
