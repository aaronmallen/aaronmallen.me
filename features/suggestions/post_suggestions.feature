Feature: Suggested edits on a blog post
  An agent suggests edits to a draft or scheduled post, and the owner accepts or rejects them from the editor.

  Background:
    Given I am signed in to the admin

  Scenario: A post with no open suggestions shows no drawer
    Given a draft post that reads "teh cat sat"
    And a draft post that reads "teh dog ran"
    And the suggested edits for post 2:
      | original | replacement | status   |
      | teh      | the         | rejected |
    When I visit "/admin/posts/new"
    Then the editor shows no suggestions
    When I visit "/admin/posts/1/edit"
    Then the editor shows no suggestions
    When I visit "/admin/posts/2/edit"
    Then the editor shows no suggestions
    When I visit "/admin/posts/2/edit?review=1"
    Then the editor shows no suggestions

  Scenario: The editor lists each open edit in a drawer
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement | reason |
      | teh      | the         | typo   |
      | sat      | slept       | tense  |
    When I visit "/admin/posts/1/edit"
    Then the editor holds the suggestions drawer headed "Suggestions"
    And the suggestions banner says "2 suggestions"
    And the suggestions drawer is shut
    And the suggestions read:
      | before | after | reason |
      | teh    | the   | typo   |
      | sat    | slept | tense  |
    And the suggested edits offer "Accept Reject Accept Reject"
    And the suggestions offer "Accept all, Reject all" for every edit
    And the page has no axe breaches in light or dark
    When I review the suggestions
    Then the suggestions drawer is open
    And the page has no axe breaches in light or dark

  Scenario: The drawer opens on load when asked to
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I visit "/admin/posts/1/edit?review=1"
    Then the suggestions drawer is open

  Scenario: Accept in the drawer sends only the edit and applies it
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I visit "/admin/posts/1/edit"
    And I press Accept on the first suggestion with an unsaved title, noting what the browser sends
    Then the browser sent only the edit and the CSRF token
    And the suggestion toast says "Suggestion applied"
    And post 1 reads "the cat sat"

  Scenario: The drawer stays open after one decision and closes after the last
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
      | sat      | slept       |
    When I visit "/admin/posts/1/edit"
    And I review the suggestions
    And I press "Accept" on the first suggestion
    Then the suggestion toast says "Suggestion applied"
    And the toast shows above the suggestions drawer
    And the suggestions drawer is open
    And the suggestions show 1 edit
    And the accepted text fills the body field as "the cat sat"
    And the accepted text shows in the preview as "the cat sat"
    And the suggestions read:
      | before | after |
      | sat    | slept |
    When I press "Accept" on the first suggestion
    Then the editor shows no suggestions
    And no suggestions banner shows
    And post 1 reads "the cat slept"
    And the edits on post 1 stand as "accepted accepted"

  Scenario: Reject in the drawer keeps it open with the rest
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
      | sat      | slept       |
    When I visit "/admin/posts/1/edit"
    And I review the suggestions
    And I press "Reject" on the first suggestion
    Then the suggestions drawer is open
    And the suggestions show 1 edit
    And the suggestion toast says "Suggestion rejected"
    And post 1 reads "teh cat sat"
    And the edits on post 1 stand as "rejected pending"

  Scenario: Accept all applies every edit and closes the drawer
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
      | sat      | slept       |
    When I visit "/admin/posts/1/edit"
    And I review the suggestions
    And I press "Accept all" for every suggestion
    Then the suggestion toast says "2 suggestions applied"
    And the suggestions drawer is shut
    And post 1 reads "the cat slept"

  Scenario: Reject all rejects every edit from the drawer
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
      | sat      | slept       |
    When I visit "/admin/posts/1/edit"
    And I review the suggestions
    And I press "Reject all" for every suggestion
    Then the suggestion toast says "2 suggestions rejected"
    And the editor shows no suggestions
    And the edits on post 1 stand as "rejected rejected"

  Scenario: Accepting one edit returns to the open drawer
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
      | sat      | slept       |
    When I accept suggested edit "1" on post 1
    Then the suggestion decision sends me to "/admin/posts/1/edit?review=1"
    And post 1 reads "the cat sat"
    And the edits on post 1 stand as "accepted pending"

  Scenario: Accepting every edit returns to the shut drawer
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
      | sat      | slept       |
    When I accept every suggested edit on post 1
    Then the suggestion decision sends me to "/admin/posts/1/edit"
    And post 1 reads "the cat slept"

  Scenario: Accept all of one edit names it in the singular
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I accept every suggested edit on post 1
    And I follow the suggestion decision
    Then the suggestion toast says "Suggestion applied"

  Scenario: Accept all skips an edit whose text has gone
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
      | dog      | cat         |
    When I accept every suggested edit on post 1
    Then post 1 reads "the cat sat"
    And the edits on post 1 stand as "accepted stale"

  Scenario Outline: An edit that no longer applies is applied nowhere
    Given a draft post that reads "<body>"
    And the suggested edits for post 1:
      | original   | replacement   |
      | <original> | <replacement> |
    When I accept every suggested edit on post 1
    Then post 1 reads "<body>"
    And the edits on post 1 stand as "stale"
    When I follow the suggestion decision
    Then the suggestion toast says "Nothing applied · every edit went stale"

    Examples:
      | body                | original | replacement |
      | teh cat sat         | dog      | cat         |
      | teh cat and teh dog | teh      | the         |

  Scenario: An edit applies only to the text it names
    Given a draft post that reads "one teh two teh three"
    And a draft post that reads "call \1 back"
    And a draft post that reads "teh cat and teh dog sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh two  | the two     |
    And the suggested edits for post 2:
      | original | replacement |
      | \1       | \2          |
    And the suggested edits for post 3:
      | original | replacement |
      | teh      | the         |
      | sat      | slept       |
    When I accept every suggested edit on post 1
    And I accept every suggested edit on post 2
    And I accept every suggested edit on post 3
    Then post 1 reads "one the two teh three"
    And post 2 reads "call \2 back"
    And post 3 reads "teh cat and teh dog slept"

  Scenario: An edit that no longer applies offers only Dismiss
    Given a draft post that reads "the cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I visit "/admin/posts/1/edit"
    Then the suggested edit is marked "stale"
    And the suggested edits offer "Dismiss"
    When I accept suggested edit "1" on post 1
    Then the edits on post 1 stand as "stale"
    And post 1 reads "the cat sat"

  Scenario: An edit marked stale stays stale until dismissed
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement | status |
      | teh      | the         | stale  |
    When I visit "/admin/posts/1/edit"
    Then the suggested edit is marked "stale"
    And the suggested edits offer "Dismiss"
    When I accept every suggested edit on post 1
    Then the edits on post 1 stand as "stale"
    And post 1 reads "teh cat sat"
    When I follow the suggestion decision
    Then the suggestion toast says "Nothing applied · every edit went stale"
    When I accept suggested edit "1" on post 1
    And I follow the suggestion decision
    Then the suggestion toast says "Nothing applied · every edit went stale"
    When I reject suggested edit "1" on post 1
    Then the edits on post 1 stand as "rejected"

  Scenario: Reject all dismisses a stale edit and clears the drawer
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement | status |
      | teh      | the         | stale  |
    When I reject every suggested edit on post 1
    Then the edits on post 1 stand as "rejected"
    When I follow the suggestion decision
    Then the editor shows no suggestions

  Scenario: An edit across a line break applies to a body saved from the editor
    Given a draft post that reads "teh"
    And the suggested edits for post 1:
      | original          | replacement               |
      | one{newline}line  | one{newline}the line      |
    When I visit "/admin/posts/1/edit"
    And I write the post body "line one{newline}line two" and save the draft
    And I accept suggested edit "1" on post 1
    Then post 1 reads "line one{newline}the line two"

  Scenario: Rejecting one edit leaves the body alone
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
      | sat      | slept       |
    When I reject suggested edit "1" on post 1
    Then the suggestion decision sends me to "/admin/posts/1/edit?review=1"
    And the edits on post 1 stand as "rejected pending"
    And post 1 reads "teh cat sat"
    When I follow the suggestion decision
    Then the suggestion toast says "Suggestion rejected"

  Scenario: Rejecting every edit returns to the editor
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
      | sat      | slept       |
    When I reject every suggested edit on post 1
    Then the suggestion decision sends me to "/admin/posts/1/edit"
    And the edits on post 1 stand as "rejected rejected"
    When I follow the suggestion decision
    Then the suggestion toast says "2 suggestions rejected"

  Scenario: A published post hides its suggestions and keeps them pending
    Given a published post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I visit "/admin/posts/1/edit"
    Then the editor shows no suggestions
    And the editor offers no suggestion decisions for post 1
    And the editor keeps the edit note box and dialog
    When I accept suggested edit "1" on post 1
    Then the edits on post 1 stand as "pending"
    And post 1 reads "teh cat sat"
    When I accept every suggested edit on post 1
    Then the suggestion decision sends me to "/admin/posts/1/edit"
    And the edits on post 1 stand as "pending"
    And post 1 reads "teh cat sat"
    When I follow the suggestion decision
    Then the suggestion toast says "Not applied · the post is published"

  Scenario: A scheduled post takes suggested edits
    Given a scheduled post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I visit "/admin/posts/1/edit"
    Then the editor holds the suggestions drawer headed "Suggestions"
    When I accept suggested edit "1" on post 1
    Then post 1 reads "the cat sat"

  Scenario: A decision on a post with no suggestions answers 404
    Given a draft post that reads "teh cat sat"
    When I accept every suggested edit on post 1
    Then the suggestion decision answers 404
    When I reject every suggested edit on post 0
    Then the suggestion decision answers 404

  Scenario: A settled edit is left alone on a second decision
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I accept every suggested edit on post 1
    And I accept every suggested edit on post 1
    Then the suggestion decision answers 302
    And the edits on post 1 stand as "accepted"

  Scenario: Rejecting twice says nothing was left to reject
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I reject every suggested edit on post 1
    And I reject every suggested edit on post 1
    And I follow the suggestion decision
    Then the suggestion toast says "Nothing to reject"

  Scenario: A decision ignores an edit from another post
    Given a draft post that reads "teh cat sat"
    And a draft post that reads "teh dog ran"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    And the suggested edits for post 2:
      | original | replacement |
      | teh      | the         |
    When I reject suggested edit "2" on post 1
    Then the edits on post 1 stand as "pending"
    And the edits on post 2 stand as "pending"

  Scenario Outline: A decision with an edit ID that is not a plain number decides nothing
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I send the suggestion form "<form>" to "/admin/posts/1/suggestions/<decision>"
    Then the suggestion decision answers 302
    And the edits on post 1 stand as "pending"
    And post 1 reads "teh cat sat"

    Examples:
      | form           | decision |
      | edit_id[]=1    | accept   |
      | edit_id=1abc   | accept   |
      | edit_id=1abc   | reject   |

  Scenario: A decision without a CSRF token is turned away
    Given a draft post that reads "teh cat sat"
    And the suggested edits for post 1:
      | original | replacement |
      | teh      | the         |
    When I send the suggestion form to "/admin/posts/1/suggestions/accept" without a CSRF token
    Then the suggestion decision answers 403
    And the edits on post 1 stand as "pending"

  Scenario Outline: A visitor who is not signed in cannot decide on a post's edits
    When a visitor sends a suggestion decision to "/admin/posts/1/suggestions/<decision>"
    Then the suggestion decision answers 403

    Examples:
      | decision |
      | accept   |
      | reject   |
