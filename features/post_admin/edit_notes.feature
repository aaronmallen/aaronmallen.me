Feature: Edit notes on a published post
  A change to a published post's body asks for a note in a dialog, and the details drawer lists the notes to reword.

  Background:
    Given I am signed in to the admin
    And I wrote a published post "Hello" with:
      | body | one |

  Scenario: An unchanged body saves without asking
    When I open the editor for "Hello"
    Then the post field "What changed and why" is missing
    And the post admin does not show "What changed and why"
    When I fill in the post "Title" with "Changed"
    And I save the post
    Then the post toast says "Saved"
    And no post dialog is open
    And the posts table has a row with:
      | title   |
      | Changed |

  Scenario: A change in newline style alone does not ask
    Given I wrote a published post "Lines" with:
      | body | one\ntwo |
    When I open the editor for "Lines"
    And I set the post body to "one\r\ntwo" by script
    And I save the post
    Then the post toast says "Saved"

  Scenario: A body change asks for the note in a dialog with the full Markdown editor and saves nothing yet
    When I open the editor for "Hello"
    And I fill in the post body with:
      """
      two
      """
    And I save the post
    Then the post note dialog asks "What changed and why"
    And the post note dialog offers Write, Preview and the toolbar
    And the body of the post "Hello" is "one"
    And the page has no axe breaches in light or dark

  Scenario: Confirming the note saves the post and the note
    When I open the editor for "Hello"
    And I fill in the post body with:
      """
      two
      """
    And I save the post
    And I fill in the post note with "Fixed a typo"
    And I save the post note
    Then the post toast says "Saved"
    And the body of the post "Hello" is "two"
    And the post "Hello" has the edit notes "Fixed a typo"

  Scenario Outline: Leaving the note dialog saves nothing and hands focus back to Save
    When I open the editor for "Hello"
    And I fill in the post body with:
      """
      two
      """
    And I save the post
    And I leave the post note dialog by <way>
    Then no post dialog is open
    And the focus is on the post's Save button
    And the body of the post "Hello" is "one"

    Examples:
      | way                |
      | Cancel             |
      | a click outside it |
      | Escape             |

  Scenario: A failed save with a note shows it inline and saves without asking again
    When I open the editor for "Hello"
    And I fill in the post body with:
      """
      two
      """
    And I fill in the post "Title" with " "
    And I save the post
    And I fill in the post note with "Fixed a typo"
    And I save the post note
    Then no post dialog is open
    And the post field "What changed and why" holds "Fixed a typo"
    When I fill in the post "Title" with "Hello"
    And I save the post
    Then the post toast says "Saved"
    And the post "Hello" has the edit notes "Fixed a typo"

  Scenario: A blank note shows its error inline without the dialog
    When I open the editor for "Hello"
    And I fill in the post body with:
      """
      two
      """
    And I save the post
    And I save the post note
    Then the post field error reads "Say what changed and why. A published post needs a note when its body changes."
    And no post dialog is open
    And the post field "What changed and why" holds ""

  Scenario Outline: A draft or scheduled post never asks
    Given I wrote a <status> post "Quiet" with:
      | body | one |
    When I open the editor for "Quiet"
    And I fill in the post body with:
      """
      two
      """
    And I press the post button "Save draft"
    Then the post toast says "Draft saved"
    And there is no post note dialog

    Examples:
      | status    |
      | draft     |
      | scheduled |

  Scenario: The drawer lists the notes newest first, dated and in Markdown
    Given the post "Hello" has the edit notes:
      | note                | written              |
      | First               | 2026-09-01T15:00:00Z |
      | Fixed the `numbers` | 2026-09-02T15:00:00Z |
    When I open the editor for "Hello"
    And I open the post details
    Then the post edit notes read "Fixed the numbers, First"
    And the post edit note "First" is dated "2026-09-01T10:00:00-05:00"
    And the post edit note "Fixed the numbers" shows "numbers" as code
    And the post editor does not offer "Delete"
    And the page has no axe breaches in light or dark

  Scenario: A post with no notes, or a draft, shows no notes card
    Given I wrote a draft post "Draft"
    When I open the editor for "Hello"
    And I open the post details
    Then the post admin does not show "Edit notes"
    When I open the editor for "Draft"
    And I open the post details
    Then the post admin does not show "Edit notes"

  Scenario: Rewording a note saves it trimmed, keeps its time and leaves the post alone
    Given the post "Hello" has the edit notes:
      | note   | written              |
      | Before | 2026-09-01T00:00:00Z |
    And the posts row "Hello" is stamped "2026-09-01T00:00:00Z"
    When I open the editor for "Hello"
    And I open the post details
    And I reword the post edit note "Before" to "  After  "
    Then the post toast says "Note saved"
    And I am on "/admin/posts/1/edit"
    And the post "Hello" has the edit notes "After"
    And the post edit note "After" is dated "2026-08-31T19:00:00-05:00"
    And the post "Hello" was not touched since "2026-09-01T00:00:00Z"

  Scenario: A reworded note of 500 characters saves
    Given the post "Hello" has the edit notes:
      | note   |
      | Before |
    And I open the editor for "Hello"
    When I send the post form to "/admin/posts/{Hello}/edits/1" with:
      | edit[note] | {500 a} |
    Then the post "Hello" has a 500 character edit note

  Scenario Outline: A bad reword answers 422, opens that note's box and keeps the old wording
    Given the post "Hello" has the edit notes:
      | note   |
      | Before |
    And I open the editor for "Hello"
    When I send the post form to "/admin/posts/{Hello}/edits/1" with:
      | edit[note] | <note> |
    Then the post admin answers 422
    And the post edit note error reads "<error>"
    And the post "Hello" has the edit notes "Before"

    Examples:
      | note     | error                                             |
      |     | Say what changed and why. A note can't be blank.  |
      | {501 a}  | Keep the note to 500 characters or fewer.         |
      | a\u0007b | Take out the control characters.                  |

  Scenario: Rewording another post's note or a missing note is not found
    Given I wrote a published post "Other"
    And the post "Other" has the edit notes:
      | note   |
      | Before |
    And I open the editor for "Hello"
    When I send the post form to "/admin/posts/{Hello}/edits/1" with:
      | edit[note] | After |
    Then the post admin answers 404
    And the post "Other" has the edit notes "Before"
    When I open the editor for "Hello"
    And I send the post form to "/admin/posts/{Hello}/edits/999" with:
      | edit[note] | After |
    Then the post admin answers 404
