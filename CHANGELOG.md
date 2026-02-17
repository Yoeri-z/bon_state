## 0.0.2

- Fixed an internal bug that caused `Rebuilder` to block cascading updates
- Made `read` and `maybeRead` not depend on the `InheritedProvider`, added new methods `depend` and `maybeDepend` to genuinely depend on a provider

## 0.0.1

First release.
The first release included:

- Provider, and RebuildingProvider and .value variants
- Rebuilder and context.read() method.
- Shared, SharedAsync, SharedFuture, SharedStream and SharedComputed.
