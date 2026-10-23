Feature: Admin tag manager paging
  The tag manager shows a hundred tags a page. Each form in a tag's editor carries the page and the search it is
  under, so a change goes back to the same place, or to the last page when the change empties the one it was on.

  Background:
    Given I am signed in to the admin
    And the tag manager holds 98 public filler tags from "ar-"
    And the tag manager holds the public tags "ruby, rust, rails, elixir, go"
    And the tag manager holds the private tags "rest"

  Scenario: The first page links to the next
    When I visit "/admin/settings/tagging"
    Then the tag manager shows ".tag-name" reading "#go"
    And the tag manager shows no ".tag-name" reading "#rails"
    And the tag manager shows "nav.pager a[rel='next'][href='/admin/settings/tagging?scope=public&page=2#tags']" reading "Older"

  Scenario: A later page keeps the scope and the search
    When I visit "/admin/settings/tagging?q=r&page=2"
    Then the tag manager lists ".tag-name" as "#ruby, #rust"
    And the tag manager shows "nav.pager a[rel='prev'][href='/admin/settings/tagging?scope=public&q=r#tags']" reading "Newer"

  Scenario: The forms in an editor carry the page and search they are under
    When I visit "/admin/settings/tagging?page=2"
    Then the tag manager shows "#tag-{public:ruby}-form input[name='page'][value='2']"
    When I visit "/admin/settings/tagging?q=r"
    Then the tag manager shows "#tag-{public:rails}-form input[name='q'][value='r']"
    And the tag manager shows "#tag-{public:rails}-editor form:not([id]) input[name='q'][value='r']"
    When I visit "/admin/settings/tagging?q=r&page=2"
    Then the tag manager shows "#tag-{public:ruby}-editor form[action$='/delete'] input[name='q'][value='r']"
    And the tag manager shows "#tag-{public:ruby}-editor form[action$='/delete'] input[name='page'][value='2']"

  Scenario: A refused rename on a later page says why against its row
    When I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | tag[name] | " " |
      | page      | 2   |
    Then the tag manager shows "#tag-{public:ruby}-name-error"

  Scenario: A refused rename keeps the search and the page
    When I post to the tag manager at "/admin/tags/{public:rust}" with:
      | tag[name] | " " |
      | q         | r   |
      | page      | 2   |
    Then the tag manager answers 422
    And the tag manager lists ".tag-name" as "#ruby, #rust"
    And the tag manager shows "#tag-{public:rust}-editor.tag-editor-open"
    And the tag manager shows "#tag-{public:rust}-name-error"

  Scenario: A rename goes back to the search
    When I post to the tag manager at "/admin/tags/{public:rust}" with:
      | tag[name] | crab   |
      | scope     | public |
      | q         | r      |
    Then the tag manager lands on "/admin/settings/tagging?scope=public&q=r#tags"

  Scenario: A rename goes back to the page and the search
    When I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | tag[name] | rubyist |
      | scope     | public  |
      | q         | r       |
      | page      | 2       |
    Then the tag manager lands on "/admin/settings/tagging?scope=public&q=r&page=2#tags"

  Scenario: A new colour goes back to the page and the search
    When I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | tag[name]  | ruby    |
      | tag[color] | mk-pink |
      | q          | r       |
      | page       | 2       |
    Then the tag manager lands on "/admin/settings/tagging?scope=public&q=r&page=2#tags"

  Scenario: A removal goes back to the page and the search
    When I post to the tag manager at "/admin/tags/{public:rust}/delete" with:
      | q    | r |
      | page | 2 |
    Then the tag manager lands on "/admin/settings/tagging?scope=public&q=r&page=2#tags"

  Scenario: A rename that empties the page goes back to the last page
    When I post to the tag manager at "/admin/tags/{public:rust}/delete" with:
      | q    | r |
      | page | 2 |
    And I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | tag[name] | gem |
      | q         | r   |
      | page      | 2   |
    Then the tag manager lands on "/admin/settings/tagging?scope=public&q=r#tags"

  Scenario: A removal that empties the page goes back to the last page
    When I post to the tag manager at "/admin/tags/{public:rust}/delete" with:
      | q    | r |
      | page | 2 |
    And I post to the tag manager at "/admin/tags/{public:ruby}/delete" with:
      | q    | r |
      | page | 2 |
    Then the tag manager lands on "/admin/settings/tagging?scope=public&q=r#tags"

  Scenario: The count holds every tag that matches, not just the page
    When I visit "/admin/settings/tagging?q=r"
    Then the tag manager shows ".card-blurb" reading "102 tags"

  Scenario: The tag manager draws no pager when one page holds every tag
    When I visit "/admin/settings/tagging?scope=private"
    Then the tag manager shows no "nav.pager"

  Scenario: The tag manager answers 404 past the last page
    Then visiting "/admin/settings/tagging?page=3" answers 404
