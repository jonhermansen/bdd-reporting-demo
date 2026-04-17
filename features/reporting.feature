Feature: Reporting demo
  Exercises the gamut of cucumber-js reporting outcomes so we can see
  how each reporter surfaces pass/fail/skip/pending/retry/flaky/logs.

  @pass
  Scenario: Fast passing scenario
    Given the demo is set up
    Then the test passes

  @pass @slow
  Scenario: Slow passing scenario
    Given the demo is set up
    When I wait 300 ms
    Then the test passes

  @fail
  Scenario: Deterministic failure
    Given the demo is set up
    Then I assert that 1 equals 2

  @skip
  Scenario: Skipped via tag filter
    Given the demo is set up
    Then this step never runs

  @pending
  Scenario: Pending (unimplemented) step
    Given the demo is set up
    When I hit a pending step

  @flaky-retry
  Scenario: Passes on the third attempt
    Given the demo is set up
    When I increment the retry counter "flaky-retry"
    Then the counter "flaky-retry" must be at least 3

  @flaky-random
  Scenario: Fails 40% of the time at random
    Given the demo is set up
    Then I randomly fail 40 percent of the time

  @logs
  Scenario: Scenario with log + attachment
    Given the demo is set up
    When I log "hello from the demo"
    And I attach text "some diagnostic payload"
    Then the test passes

  Scenario Outline: Parameterised passing scenario
    Given I have the number <value>
    Then it should be positive

    Examples:
      | value |
      | 1     |
      | 2     |
      | 3     |
