Feature: Release
  mise run release gives the newest commit that is not empty an annotated tag named for the next CalVer
  version, once the changelog and CI agree.

  Scenario Outline: release counts the version from the tags in #382
    Given a git repo tagged "1.0.0, 1.0.1, 1.0.2, 1.1.0, 1.2.0, 1.3.0, 1.4.0, 1.4.1, 26.9.0, 26.9.1, 26.9.2, 26.9.3, 26.9.4, 26.10.0, 26.10.1, 26.10.2"
    Then the next version on "<date>" is "<version>"

    Examples:
      | date       | version |
      | 2026-10-03 | 26.10.3 |
      | 2026-11-01 | 26.11.0 |
      | 2026-09-30 | 26.9.5  |
      | 2026-01-15 | 26.1.0  |

  Scenario: release counts past 9 by number, not by text
    Given a git repo tagged "26.12.0, 26.12.1, 26.12.2, 26.12.3, 26.12.4, 26.12.5, 26.12.6, 26.12.7, 26.12.8, 26.12.9, 26.12.10"
    Then the next version on "2026-12-31" is "26.12.11"

  Scenario: release names today's UTC month with no date given
    Given a git repo tagged ""
    Then the next version with no date is the first of this UTC month

  Scenario: release refuses a date in another shape
    Given a git repo tagged ""
    When I release with "2026-1-1"
    Then it fails
    And the output includes "YYYY-MM-DD"

  Scenario: release makes an annotated tag on the newest commit that is not empty, and does not push it
    Given a git repo with the changelog for "26.10.0" under two empty commits
    And the repo has a remote
    When I release with "2026-10-14"
    Then it succeeds
    And "26.10.0" is an annotated tag on the target
    And the tag "26.10.0" says "26.10.0" and carries no signature
    And the output includes "git push origin 26.10.0"
    And the remote holds no tags

  Scenario: release prints the version, the target and its CI state on a dry run and makes no tag
    Given a git repo with the changelog for "26.10.0" under two empty commits
    And CI reports "running"
    When I release with "--dry-run 2026-10-14"
    Then it succeeds
    And the dry run prints "26.10.0", the target and "CI running"
    And the repo has no tags

  Scenario: release reports an unknown CI state on a dry run when gh fails
    Given a git repo with the changelog for "26.10.0" under two empty commits
    And gh cannot read CI
    When I release with "--dry-run 2026-10-14"
    Then the output ends with "CI unknown"

  Scenario Outline: release refuses while CI has not passed
    Given a git repo with the changelog for "26.10.0" under two empty commits
    And CI reports "<state>"
    Then the release refuses, saying "<reason>"

    Examples:
      | state      | reason                       |
      | running    | CI is still running          |
      | failed     | CI did not pass              |
      | missing    | CI has not run               |
      | unreadable | Could not read the CI state |

  Scenario: release refuses a target that already carries a version tag
    Given a git repo with the changelog for "26.10.0" under two empty commits
    And the target carries the tag "26.9.4"
    Then the release refuses, saying "already carries 26.9.4"

  Scenario: release refuses while [Unreleased] still has entries
    Given a git repo with the changelog for "26.10.0" under two empty commits
    And the changelog for "26.10.0" with entries under [Unreleased]
    And I commit the changes as "Add an entry"
    Then the release refuses, saying "entries under [Unreleased]"

  Scenario: release refuses a changelog with no section for the version
    Given a git repo with the changelog for "26.10.0" under two empty commits
    And the changelog for "26.9.0"
    And I commit the changes as "Drop the section"
    Then the release refuses, saying "no section for 26.10.0"

  Scenario: release refuses when [Unreleased] does not compare from the version
    Given a git repo with the changelog for "26.10.0" under two empty commits
    And the changelog for "26.10.0" with the links:
      """
      [Unreleased]: https://github.com/aaronmallen/aaronmallen.me/compare/26.9.4...HEAD
      [26.10.0]: https://github.com/aaronmallen/aaronmallen.me/compare/26.9.4...26.10.0
      """
    And I commit the changes as "Leave [Unreleased] behind"
    Then the release refuses, saying "[Unreleased] link does not compare from 26.10.0"

  Scenario: release refuses when the version has no compare link
    Given a git repo with the changelog for "26.10.0" under two empty commits
    And the changelog for "26.10.0" with the links:
      """
      [Unreleased]: https://github.com/aaronmallen/aaronmallen.me/compare/26.10.0...HEAD
      """
    And I commit the changes as "Drop the link"
    Then the release refuses, saying "no compare link for 26.10.0"

  Scenario: release with --skip-ci tags anyway and says it skipped the check
    Given a git repo with the changelog for "26.10.0" under two empty commits
    And CI reports "failed"
    When I release with "--skip-ci 2026-10-14"
    Then it succeeds
    And the output includes "Skipped the CI check on" and the target
    And "26.10.0" is an annotated tag on the target

  Scenario: release lists the variables .env.example gained since the last tag on a dry run, in file order
    Given a git repo
    And the changelog for "26.10.0"
    And the file "repo/.env.example":
      """
      # Some
      KEPT=1
      # MOVED=
      GONE=
      """
    And I commit the changes as "Add the example"
    And the target carries the tag "26.9.4"
    And the file "repo/.env.example":
      """
      # MOVED=
      # Some
      KEPT=1
      ADDED=
      # COMMENTED=2
      """
    And I commit the changes as "Change the example"
    When I release with "--dry-run 2026-10-14"
    Then the output ends with:
      """
      New in .env.example since 26.9.4:
        ADDED
        COMMENTED
      """

  Scenario: release refuses, dry run too, while a spec names a migration a tag holds
    Given a git repo with specs that name two migrations
    And the tag "26.9.4" on the commit that adds the first migration
    Then the release refuses, saying "spec/db/tasks_spec.rb"
    When I release with "--dry-run 2026-10-14"
    Then it fails
    And the output ends with:
      """
      These specs name a migration a tag already shipped. Take it out of each, or delete the spec:
      spec/db/tasks_spec.rb
      """

  Scenario: release goes on while no tag holds a migration a spec names
    Given a git repo with specs that name two migrations
    When I release with "--dry-run 2026-10-14"
    Then it succeeds

  Scenario: release in a jj repo skips the empty commits on top
    Given a jj repo with the changelog for "26.10.0" under an empty commit
    When I release with "2026-10-14"
    Then it succeeds
    And "26.10.0" is an annotated tag on the target

  Scenario: release in a jj repo names the same target on a dry run
    Given a jj repo with the changelog for "26.10.0" under an empty commit
    When I release with "--dry-run 2026-10-14"
    Then the dry run prints "26.10.0", the target and "CI passed"
