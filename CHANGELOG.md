## Unreleased

## 0.6.1

* Add `#alive?` to the watcher returned by `Watchcat.watch` for checking whether the background watcher thread is still running.
* Fix `ignore_access` being a no-op on macOS: FSEvents has no `Access` event kind, so a plain read was surfacing as an unclassified `Modify(Metadata)` event instead and passing the filter unfiltered.

## 0.6.0

* Add `#watch`, `#unwatch`, and `#watched` to the watcher returned by `Watchcat.watch` for dynamically managing watched paths.
* Add `Watchcat::EventHandler` for handling events with callback methods.
* Add `Watchcat::Event#src_path` and `Watchcat::Event#dest_path` for move/rename events.
* Add `patterns`, `ignore_patterns`, and `ignore_directories` options to `Watchcat.watch`.
* Fix `Watchcat::Executor#stop` so that it is a no-op in a forked child process, and make it idempotent.

## 0.5.2

* Support Ruby 4.0

## 0.5.1

* Fix missing executable files

## 0.5.0

* Rework the debounce feature. Now all events are debounced.
* Add `init` option to CLI

## 0.4.0

* Add CLI
* Add filters option

## 0.3.0

* Support Windows
