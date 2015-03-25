# Change Log

## [2.6.2](https://github.com/ReactKit/SwiftTask/tree/2.6.2) (2015-03-02)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/2.6.1...2.6.2)

**Merged pull requests:**

- Add `\_` to omit parameter name [\#24](https://github.com/ReactKit/SwiftTask/pull/24) ([mono0926](https://github.com/mono0926))

## [2.6.1](https://github.com/ReactKit/SwiftTask/tree/2.6.1) (2015-01-26)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/2.6.0...2.6.1)

**Merged pull requests:**

- App Extensions' target warning [\#23](https://github.com/ReactKit/SwiftTask/pull/23) ([mono0926](https://github.com/mono0926))

## [2.6.0](https://github.com/ReactKit/SwiftTask/tree/2.6.0) (2015-01-21)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/2.5.1...2.6.0)

**Merged pull requests:**

- Remove SwiftState dependency for significant performance improvement. [\#22](https://github.com/ReactKit/SwiftTask/pull/22) ([inamiy](https://github.com/inamiy))

## [2.5.1](https://github.com/ReactKit/SwiftTask/tree/2.5.1) (2015-01-14)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/2.5.0...2.5.1)

## [2.5.0](https://github.com/ReactKit/SwiftTask/tree/2.5.0) (2015-01-11)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/2.4.0...2.5.0)

**Closed issues:**

- Cocoapods 0.36 beta support [\#20](https://github.com/ReactKit/SwiftTask/issues/20)

**Merged pull requests:**

- Add \_InitPause & \_InitResume states to safely invoke \_performInitClosure. [\#21](https://github.com/ReactKit/SwiftTask/pull/21) ([inamiy](https://github.com/inamiy))

## [2.4.0](https://github.com/ReactKit/SwiftTask/tree/2.4.0) (2014-12-26)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/2.3.0...2.4.0)

**Merged pull requests:**

- Add Carthage 0.5 support. [\#19](https://github.com/ReactKit/SwiftTask/pull/19) ([inamiy](https://github.com/inamiy))

- Don't propagate pause/resume/cancel to upstream. [\#18](https://github.com/ReactKit/SwiftTask/pull/18) ([inamiy](https://github.com/inamiy))

## [2.3.0](https://github.com/ReactKit/SwiftTask/tree/2.3.0) (2014-12-20)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/2.2.3...2.3.0)

**Merged pull requests:**

- Add paused-init feature. [\#17](https://github.com/ReactKit/SwiftTask/pull/17) ([inamiy](https://github.com/inamiy))

- Fix chained-task-progress. [\#16](https://github.com/ReactKit/SwiftTask/pull/16) ([inamiy](https://github.com/inamiy))

## [2.2.3](https://github.com/ReactKit/SwiftTask/tree/2.2.3) (2014-12-14)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/2.2.2...2.2.3)

## [2.2.2](https://github.com/ReactKit/SwiftTask/tree/2.2.2) (2014-12-12)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/2.2.1...2.2.2)

**Merged pull requests:**

- Fix 4a7fc95 by updating SwiftState to v1.1.1 [\#15](https://github.com/ReactKit/SwiftTask/pull/15) ([inamiy](https://github.com/inamiy))

## [2.2.1](https://github.com/ReactKit/SwiftTask/tree/2.2.1) (2014-12-11)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/2.2.0...2.2.1)

**Merged pull requests:**

- Fix b43e878 where xcodebuild sometimes failed by removing Carthage.build folder in xcodeproj. [\#14](https://github.com/ReactKit/SwiftTask/pull/14) ([inamiy](https://github.com/inamiy))

## [2.2.0](https://github.com/ReactKit/SwiftTask/tree/2.2.0) (2014-12-10)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/2.1.1...2.2.0)

**Merged pull requests:**

- Fix 4dcdfcc xcworkspace. [\#13](https://github.com/ReactKit/SwiftTask/pull/13) ([inamiy](https://github.com/inamiy))

- Fix cf78ad5 by avoiding nested-xcodeproj which cause carthage-build failure. [\#12](https://github.com/ReactKit/SwiftTask/pull/12) ([inamiy](https://github.com/inamiy))

- Add Carthage 0.3 support. [\#11](https://github.com/ReactKit/SwiftTask/pull/11) ([inamiy](https://github.com/inamiy))

## [2.1.1](https://github.com/ReactKit/SwiftTask/tree/2.1.1) (2014-12-06)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/2.1.0...2.1.1)

## [2.1.0](https://github.com/ReactKit/SwiftTask/tree/2.1.0) (2014-12-05)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/2.0.0...2.1.0)

**Merged pull requests:**

- Fix pause/cancel bug when chained with then/success/catch. [\#10](https://github.com/ReactKit/SwiftTask/pull/10) ([inamiy](https://github.com/inamiy))

- Add retryable feature. [\#9](https://github.com/ReactKit/SwiftTask/pull/9) ([inamiy](https://github.com/inamiy))

## [2.0.0](https://github.com/ReactKit/SwiftTask/tree/2.0.0) (2014-11-18)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/1.0.0...2.0.0)

**Merged pull requests:**

- Ver 2.0.0: Rename then/catch to then/success/failure. [\#8](https://github.com/ReactKit/SwiftTask/pull/8) ([inamiy](https://github.com/inamiy))

## [1.0.0](https://github.com/ReactKit/SwiftTask/tree/1.0.0) (2014-10-15)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/0.1.0...1.0.0)

**Implemented enhancements:**

- Create helper tasks for common frameworks e.g. GCD, Foundation, UIKit, etc. [\#3](https://github.com/ReactKit/SwiftTask/issues/3)

**Closed issues:**

- Graphviz support [\#4](https://github.com/ReactKit/SwiftTask/issues/4)

**Merged pull requests:**

- Delete funny custom operators. [\#7](https://github.com/ReactKit/SwiftTask/pull/7) ([inamiy](https://github.com/inamiy))

- Fix code for Xcode6.1-GM. [\#6](https://github.com/ReactKit/SwiftTask/pull/6) ([inamiy](https://github.com/inamiy))

## [0.1.0](https://github.com/ReactKit/SwiftTask/tree/0.1.0) (2014-09-17)

[Full Changelog](https://github.com/ReactKit/SwiftTask/compare/0.0.1...0.1.0)

**Merged pull requests:**

- Fix retain-cycle bug. [\#5](https://github.com/ReactKit/SwiftTask/pull/5) ([inamiy](https://github.com/inamiy))

- Add task.then\(\) which can handle both fulfilled & rejected. [\#2](https://github.com/ReactKit/SwiftTask/pull/2) ([inamiy](https://github.com/inamiy))

- Improve future binding. [\#1](https://github.com/ReactKit/SwiftTask/pull/1) ([inamiy](https://github.com/inamiy))

## [0.0.1](https://github.com/ReactKit/SwiftTask/tree/0.0.1) (2014-08-23)



\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*