Feature: Admin toast
  A save tells the owner it worked with a toast on the page it lands on, shown once.

  Background:
    Given I am signed in to the admin

  Scenario: Saving a draft shows the toast once on the next page
    When I save a draft post titled "Hello" from the post editor
    Then the admin markup holds "main + [role='status'][data-toast] .toast:has-text('Draft saved')"
    And I see "Draft saved"
    When I load the admin page again
    Then the admin markup lacks "[data-toast]"

  Scenario: The toast goes away after it has shown
    When I save a draft post titled "Hello" from the post editor
    Then I see "Draft saved"
    And the toast is gone within 6 seconds

  Scenario: A page with no save before it shows no toast
    When I visit "/admin/posts/new"
    Then the admin markup lacks "[data-toast]"

  Scenario: The new post page passes axe
    When I visit "/admin/posts/new"
    Then the page has no axe breaches in light or dark
