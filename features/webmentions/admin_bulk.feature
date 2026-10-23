Feature: Moderating many webmentions at once in the admin
  A bar above the list acts on every webmention ticked, and says how many
  changed. It refuses a batch it cannot act on whole.

  Background:
    Given I am signed in to the admin
    And a published post "Hello" taking webmentions

  Scenario: The list draws one bar, a box on each row named for its author, and no text field
    Given these webmentions on the post "Hello":
      | author_name  |
      | Ada Lovelace |
      | Grace        |
    When I visit "/admin/webmentions"
    Then the webmention page has the element "form#webmention-bulk[action='/admin/webmentions/bulk'][method='post']"
    And the webmention page has the element ".wm-card input[type='checkbox'][name='ids[]'][form='webmention-bulk'][aria-label='Select Ada Lovelace']"
    And the webmention page has no element "form#webmention-bulk input:not([type='hidden']):not([type='checkbox'])"
    And the bar actions show in the page as served, so they work with scripts off
    And the bar's buttons wear:
      | approved | fa-solid fa-check      |
      | ignored  | fa-regular fa-eye-slash |
      | spam     | fa-solid fa-ban        |

  Scenario Outline: The <status> list offers <acts>
    Given these webmentions on the post "Hello":
      | author_name | status   |
      | Ada         | <status> |
    When I visit "/admin/webmentions?status=<status>"
    Then the webmention bar offers "<acts>"

    Examples:
      | status   | acts                   |
      | pending  | approved, ignored, spam |
      | approved | ignored, spam          |
      | ignored  | approved, spam         |
      | spam     | approved, ignored      |

  Scenario: An empty list draws no bar
    When I visit "/admin/webmentions?status=spam"
    Then there is no webmention bar

  Scenario: The bar keeps the filter and the page
    Given 101 approved webmentions on the post "Hello"
    When I visit "/admin/webmentions?status=approved&page=2"
    Then the webmention page has the element "form#webmention-bulk input[name='status'][value='approved']"
    And the webmention page has the element "form#webmention-bulk input[name='page'][value='2']"

  Scenario: The bar's actions hide until a row is ticked
    Given these webmentions on the post "Hello":
      | author_name |
      | Ada         |
      | Grace       |
    When I visit "/admin/webmentions"
    Then the webmention bar is hidden
    When I tick the webmention from "Grace"
    Then the webmention bar is shown
    And the page has no axe breaches in light or dark

  Scenario Outline: <button> on the ticked webmentions changes them, leaves the rest and says how many
    Given these webmentions on the post "Hello":
      | author_name |
      | Ada         |
      | Grace       |
      | Alan        |
    When I visit "/admin/webmentions"
    And I tick the webmention from "Ada"
    And I tick the webmention from "Alan"
    And I press "<button>" on the webmention bar
    Then I see "<toast>"
    And the webmentions table has a row with:
      | author_name | status   |
      | Ada         | <status> |
    And the webmentions table has a row with:
      | author_name | status   |
      | Alan        | <status> |
    And the webmentions table has a row with:
      | author_name | status  |
      | Grace       | pending |

    Examples:
      | button  | status   | toast                         |
      | Approve | approved | Approved 2 webmentions        |
      | Ignore  | ignored  | Ignored 2 webmentions         |
      | Spam    | spam     | Marked 2 webmentions as spam  |

  Scenario: Select all ignores every webmention on the page
    Given these webmentions on the post "Hello":
      | author_name |
      | Ada         |
      | Grace       |
      | Alan        |
    When I visit "/admin/webmentions"
    And I tick every webmention on the page
    And I press "Ignore" on the webmention bar
    Then I see "Ignored 3 webmentions"
    And the webmentions table has no row with:
      | status  |
      | pending |

  Scenario: Spam on one ticked webmention says so in the singular
    Given these webmentions on the post "Hello":
      | author_name | status |
      | Ada         | pending |
      | Barbara     | spam    |
    When I visit "/admin/webmentions"
    And I tick the webmention from "Ada"
    And I press "Spam" on the webmention bar
    Then I see "Marked 1 webmention as spam"

  Scenario: Approve on the spam list approves the ticked ones, clears the spam note and lands back on spam
    Given these webmentions on the post "Hello":
      | author_name | status | spam_reason |
      | Barbara     | spam   | junk        |
    When I visit "/admin/webmentions?status=spam"
    And I tick the webmention from "Barbara"
    And I press "Approve" on the webmention bar
    Then I see "Approved 1 webmention"
    And I am on "/admin/webmentions?status=spam"
    And the webmentions table has a row with:
      | author_name | status   | spam_reason |
      | Barbara     | approved | null        |

  Scenario: A batch approve trusts the author and approves their other waiting mentions
    Given these webmentions on the post "Hello":
      | author_name | author_url               |
      | Ada         | http://203.0.113.7/about |
      | Waiting     | http://203.0.113.7/about |
    When I visit "/admin/webmentions"
    And I tick the webmention from "Ada"
    And I press "Approve" on the webmention bar
    Then the trusted_authors table holds 1 rows
    And the webmentions table has a row with:
      | author_name | status   |
      | Waiting     | approved |

  Scenario: A batch spam takes trust away, and a batch ignore gives none
    Given the trusted author "http://203.0.113.7/about"
    And these webmentions on the post "Hello":
      | author_name | author_url               |
      | Ada         | http://203.0.113.7/about |
      | Grace       | http://203.0.113.8/about |
    When I visit "/admin/webmentions"
    And I tick the webmention from "Grace"
    And I press "Ignore" on the webmention bar
    And I tick the webmention from "Ada"
    And I press "Spam" on the webmention bar
    Then the trusted_authors table holds 0 rows

  Scenario Outline: A batch <act> with a webmention that is gone changes nothing and names it
    Given these webmentions on the post "Hello":
      | author_name |
      | Ada         |
      | Grace       |
    When I visit "/admin/webmentions?status=ignored"
    And I post to the admin "/admin/webmentions/bulk" with:
      | act    | <act>   |
      | status | ignored |
      | ids[]  | 1       |
      | ids[]  | 2       |
      | ids[]  | 99      |
    Then I see "Nothing changed · webmention #99 is gone"
    And I am on "/admin/webmentions?status=ignored"
    And the webmentions table has no row with:
      | status   |
      | <act>    |

    Examples:
      | act      |
      | approved |
      | ignored  |
      | spam     |

  Scenario Outline: A batch lands on <where>
    Given 3 pending webmentions on the post "Hello"
    When I visit "/admin/webmentions"
    And I post to the admin "/admin/webmentions/bulk" with:
      | act    | approved |
      | status | <status> |
      | ids[]  | 1        |
    Then I am on "<landing>"

    Examples:
      | where                                     | status | landing                              |
      | the pending list for a filter it does not know | junk   | /admin/webmentions?status=pending  |
      | the list it came from                     | spam   | /admin/webmentions?status=spam       |

  Scenario: A batch keeps the page while it still has rows, and steps back once it empties the last one
    Given 102 pending webmentions on the post "Hello"
    When I visit "/admin/webmentions?page=2"
    And I post to the admin "/admin/webmentions/bulk" with:
      | act    | approved |
      | status | pending  |
      | page   | 2        |
      | ids[]  | 1        |
    Then I am on "/admin/webmentions?status=pending&page=2"
    When I post to the admin "/admin/webmentions/bulk" with:
      | act    | approved |
      | status | pending  |
      | page   | 2        |
      | ids[]  | 2        |
    Then I am on "/admin/webmentions?status=pending"

  Scenario: A batch with nothing ticked asks for a tick
    Given 1 pending webmentions on the post "Hello"
    When I visit "/admin/webmentions"
    And I post to the admin "/admin/webmentions/bulk" with:
      | act    | approved |
      | status | pending  |
    Then I see "Tick a webmention first"

  Scenario: A batch of more than 100 is refused before any changes
    Given 101 pending webmentions on the post "Hello"
    When I visit "/admin/webmentions"
    And I post to the admin "/admin/webmentions/bulk" with:
      | act    | approved |
      | status | pending  |
      | ids[]  | 1..101   |
    Then I see "Tick 100 webmentions or fewer"
    And the webmentions table has no row with:
      | status   |
      | approved |

  Scenario: A repeated webmention counts once
    Given 1 pending webmentions on the post "Hello"
    When I visit "/admin/webmentions"
    And I post the webmention 1 to the bar 101 times
    Then I see "Approved 1 webmention"

  Scenario: An action off the bar is refused
    Given 1 pending webmentions on the post "Hello"
    When I visit "/admin/webmentions"
    And I post to the admin "/admin/webmentions/bulk" with:
      | act    | pending |
      | status | pending |
      | ids[]  | 1       |
    Then I see "Nothing changed · pick an action from the bar"
    And the webmentions table has a row with:
      | status  |
      | pending |
