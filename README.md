# Watchcat

Simple filesystem notification library for Ruby.

## How

This gem uses [Notify](https://github.com/notify-rs/notify) to get notifications.

## Platforms

This gem supports Linux, macOS and Windows.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add watchcat

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install watchcat

## Usage

Please specify a filename or directory and callback block to `Watchcat.watch`. The callback will call when the specified file or directory is changed.

```ruby
require "watchcat"

Watchcat.watch("/tmp/test") do |e|
  pp e.paths, e.kind
end

sleep
```

The value that is passed to the callback holds the paths that changed and the file change event. For example, if a file is created under the `/tmp/test`, you will get the following output.

```
["/tmp/test/a.txt"]
#<Watchcat::EventKind:0x00007f84be7161d8 @access=nil, @create=#<Watchcat::CreateKind:0x00007f84b99eaa08 @kind="file">, @modify=nil, @remove=nil>
["/tmp/test/a.txt"]
#<Watchcat::EventKind:0x00007f84be7159b8
 @access=nil,
 @create=nil,
 @modify=#<Watchcat::ModifyKind:0x00007f84be715968 @data_change=nil, @kind="metadata", @metadata=#<Watchcat::MetadataKind:0x00007f84b99e7a60 @kind=nil>, @rename=nil>,
 @remove=nil>
["/tmp/test/a.txt"]
#<Watchcat::EventKind:0x00007f84be714dd8
 @access=#<Watchcat::AccessKind:0x00007f84b99e3708 @access_mode=#<Watchcat::AccessMode:0x00007f84b99e3640 @mode="write">, @kind="close">,
 @create=nil,
 @modify=nil,
 @remove=nil>
```

You can know what event is happened with `Watchcat::EventKind`. For example, what a file is changed or not, you can check with `Watchcat::EventKind#modify?`. Seed the following example for details.

```ruby
require "watchcat"

Watchcat.watch("/tmp/target") do |e|
  if e.kind.create?
    if e.kind.create.file?
      puts "'#{e.paths[0]}'(File) is added."
    elsif e.kind.create.folder?
      puts "'#{e.paths[0]}'(Folder) is added."
    end
  elsif e.kind.modify?
    if e.kind.modify.data_change?
      puts "'#{e.paths[0]}' is updated."
    end
  elsif e.kind.remove?
    if e.kind.remove.file?
      puts "'#{e.paths[0]}'(File) is removed."
    elsif e.kind.remove.folder?
      puts "'#{e.paths[0]}'(Folder) is removed."
    end
  end
end

sleep
```


**CAUTION** The `watchcat` doesn't normalize the events. So the result might change per the platform.


### Options

| Name                       | Description                              | Default           |
| -------------------------- | -----------------------------------------| ----------------- |
| **recursive**              | Watch a directory recursively or not.    | `true`            |
| **force_polling**          | Force to use a polling to watch.         | `false`           |
| **debounce**               | Debounce events for the same file.       | `-1`              |


### Filters Option

You can use the `filters` option to ignore specific event types:

| Key             | Description                       |
|-----------------|-----------------------------------|
| ignore_remove   | Ignore remove (delete) events     |
| ignore_access   | Ignore access events              |
| ignore_create   | Ignore create events              |
| ignore_modify   | Ignore modify events              |

Example usage:

```ruby
Watchcat.watch("/tmp/test", filters: { ignore_remove: true, ignore_access: true }) do |e|
  pp e.paths, e.kind
end
```


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/y-yagi/watchcat.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
