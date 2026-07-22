## Unreleased

* Add `Watchcat::EventHandler` for handling events with callback methods.
* Add `Watchcat::Event#src_path` and `Watchcat::Event#dest_path` for move/rename events.
* Add `patterns`, `ignore_patterns`, and `ignore_directories` options to `Watchcat.watch`.

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
