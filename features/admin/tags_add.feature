Feature: Admin tag manager adds tags
  The owner names a new tag on the public or the private tab. The tag manager folds the name to lower case, picks
  the colour its scope uses least, and says why it refused a name.

  Background:
    Given I am signed in to the admin

  Scenario: Adding a tag stores it in lower case, in one of the six colours, and says so
    When I post to the tag manager at "/admin/tags" with:
      | tag[name] | Ruby |
    Then the tag manager shows "[data-toast]" reading "Tag added"
    And the database answers "ruby, public, true" for:
      """
      select name, scope, color::text like 'mk-%' from tags
      """

  Scenario: Adding six tags spreads the six colours over them
    When I post to the tag manager at "/admin/tags" with:
      | tag[name] | one |
    And I post to the tag manager at "/admin/tags" with:
      | tag[name] | two |
    And I post to the tag manager at "/admin/tags" with:
      | tag[name] | three |
    And I post to the tag manager at "/admin/tags" with:
      | tag[name] | four |
    And I post to the tag manager at "/admin/tags" with:
      | tag[name] | five |
    And I post to the tag manager at "/admin/tags" with:
      | tag[name] | six |
    Then the database answers "6" for:
      """
      select count(distinct color) from tags
      """

  Scenario: Adding a tag gives it the colour its own scope uses least
    Given the tag manager holds these tags:
      | name  | scope   | color     |
      | a     | private | mk-pink   |
      | b     | private | mk-green  |
      | c     | private | mk-blue   |
      | d     | private | mk-violet |
      | e     | private | mk-sand   |
      | f     | public  | mk-orange |
      | g     | public  | mk-orange |
    When I post to the tag manager at "/admin/tags" with:
      | tag[name] | fresh   |
      | scope     | private |
    Then the database answers "mk-orange" for:
      """
      select color from tags where name = 'fresh'
      """

  Scenario: Adding a blank name says why
    When I post to the tag manager at "/admin/tags" with:
      | tag[name] | " " |
    Then the tag manager answers 422
    And the tag manager shows ".field-error" reading "Give the tag a name first."

  Scenario: Adding a name that is not a slug says why
    When I post to the tag manager at "/admin/tags" with:
      | tag[name] | Machine Learning |
    Then the tag manager shows ".field-error" reading "A tag is lowercase words joined by hyphens."

  Scenario: Adding a name with a control character says why
    When I post to the tag manager at "/admin/tags" with:
      | tag[name] | "ru\u0007by" |
    Then the tag manager shows ".field-error" reading "Take out the control characters."

  Scenario Outline: Adding "<name>" is refused, since it is not a slug
    When I post to the tag manager at "/admin/tags" with:
      | tag[name] | <name> |
    Then the tag manager shows ".field-error" reading "A tag is lowercase words joined by hyphens."
    And the database answers "0" for:
      """
      select count(*) from tags
      """

    Examples:
      | name        |
      | c++         |
      | -ruby       |
      | ruby-       |
      | a/b         |
      | open source |

  Scenario: Adding a name another public tag holds says why and keeps what was typed
    Given the tag manager holds the public tags "ruby"
    When I post to the tag manager at "/admin/tags" with:
      | tag[name] | Ruby |
    Then the tag manager shows ".field-error" reading "Another tag already holds that name."
    When I post to the tag manager at "/admin/tags" with:
      | tag[name] | ruby |
    Then the tag manager shows "#tag-name[value='ruby']"

  Scenario: Adding from the private tab makes a private tag and goes back to that tab
    When I post to the tag manager at "/admin/tags" with:
      | tag[name] | ruby    |
      | scope     | private |
    Then the tag manager lands on "/admin/settings/tagging?scope=private#tags"
    And the database answers "ruby, private" for:
      """
      select name, scope from tags
      """

  Scenario: Adding takes a name the other scope holds
    Given the tag manager holds the public tags "ruby"
    When I post to the tag manager at "/admin/tags" with:
      | tag[name] | ruby    |
      | scope     | private |
    Then the database answers "ruby public | ruby private" for:
      """
      select string_agg(name || ' ' || scope, ' | ' order by scope) from tags
      """

  Scenario: Adding a name the private scope holds says why and keeps the private tab
    Given the tag manager holds the private tags "ruby"
    When I post to the tag manager at "/admin/tags" with:
      | tag[name] | ruby    |
      | scope     | private |
    Then the tag manager shows ".field-error" reading "Another tag already holds that name."
    And the tag manager shows "a.seg-option.current" reading "Private"

  Scenario: A forged token adds nothing
    When I post to the tag manager at "/admin/tags" with:
      | _csrf_token | forged |
      | tag[name]   | ruby   |
    Then the tag manager answers 403
    And the database answers "0" for:
      """
      select count(*) from tags
      """

  Scenario: A forged token renames and removes nothing
    Given the tag manager holds the public tags "ruby"
    When I post to the tag manager at "/admin/tags/{public:ruby}" with:
      | _csrf_token | forged |
      | tag[name]   | hanami |
    And I post to the tag manager at "/admin/tags/1/delete" with:
      | _csrf_token | forged |
    Then the database answers "ruby" for:
      """
      select name from tags
      """
