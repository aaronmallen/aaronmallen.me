Feature: Deleting a post
  Delete sits in the foot of the details drawer, asks first and takes the post's notes and webmentions with it.

  Background:
    Given I am signed in to the admin

  Scenario: Delete asks with no count when the post received nothing, and keeps the post when I decline
    Given I wrote a draft post "Drop me"
    When I open the editor for "Drop me"
    And I open the post details
    Then the post editor offers "Delete post"
    When I click "Delete post"
    Then the post admin shows "Delete this post? You can't undo it."
    When I decline the post action
    Then the post field "Title" holds "Drop me"
    And the posts table holds 1 rows

  Scenario: Delete names the one webmention it will destroy
    Given I wrote a draft post "Drop me"
    And the post "Drop me" has received webmentions:
      | status  |
      | pending |
    When I open the editor for "Drop me"
    And I open the post details
    And I click "Delete post"
    Then the post admin shows "Delete this post and the 1 webmention it received? You can't undo it."

  Scenario: Confirming lands on the list and takes the post, its notes and webmentions, and its page
    Given I wrote a published post "Hello"
    And the post "Hello" has the edit notes:
      | note      |
      | Fixed one |
    And the post "Hello" has received webmentions:
      | status   |
      | approved |
      | pending  |
    And the post "Hello" has a social post posted
    When I open the editor for "Hello"
    And I open the post details
    And I click "Delete post"
    Then the post admin shows "Delete this post and the 2 webmentions it received? You can't undo it."
    When I confirm the post action
    Then the post toast says "Post deleted"
    And I am on "/admin/posts"
    And the post admin does not show "Hello"
    And the post_edits table holds 0 rows
    And the webmentions table holds 0 rows
    And the social_posts table has a row with:
      | post_id |
      | null    |
    And the post page "/writing/hello" is not found

  Scenario: A delete with no CSRF token is refused
    Given I wrote a published post "Hello"
    And I open the editor for "Hello"
    When I send the post form to "/admin/posts/{Hello}/delete" with:
      | _csrf_token | none |
    Then the post admin answers 403
    And the posts table holds 1 rows
