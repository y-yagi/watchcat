# Watchcat

Simple filesystem notification library for Ruby.

## How

This gem uses [Notify](https://github.com/notify-rs/notify) to get notifications.

## Platforms

This gem supports Linux and macOS. Due to the using `fork`, this doesn't support Windows now.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add watchcat

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install watchcat

## Usage

Please specify a filename or directory and callback block to `Watchcat.watch`. The callback will call when the specified file or directory is changed.

```ruby
require "watchcat"

w = Watchcat.watch("/tmp/text.txt") do |e|
  pp e.kind, e.paths
end

# Don't forget to call `stop`.
at_exit { w.stop }

sleep
```

### Options

| Name                       | Description                              | Default           |
| -------------------------- | -----------------------------------------| ----------------- |
| **recursive**              | Watch a directory recursively or not.    | `false`           |
| **force_polling**          | Force to use a polling to watch.         | `false`           |



## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/y-yagi/watchcat.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
