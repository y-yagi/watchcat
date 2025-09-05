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


## CLI

`watchcat` comes with a command-line interface that allows you to watch files and execute commands when changes occur.

### Usage

```
# Run watchcat with a config file
$ watchcat -C config.yml

# Generate a template config file
$ watchcat --init config.yml
```

### Configuration File

The configuration file should be in YAML format. Here's an example:

```yaml
watches:
  - path: "./lib"
    recursive: true
    debounce: 300
    filters:
      ignore_access: true
    patterns:
      - "*.rb"
      - "*.yml"
    actions:
      - command: "echo 'Ruby/YAML file changed: {{file_name}}'"
      - command: "rubocop {{file_path}}"
```

### Configuration Options

Each watch entry supports the following options:

| Option      | Description                                            | Default |
|-------------|--------------------------------------------------------|---------|
| path        | Directory or file path to watch (required)             | -       |
| recursive   | Watch a directory recursively or not                   | `true`  |
| debounce    | Debounce events for the same file (in milliseconds)    | `-1`    |
| filters     | Event filters (same as library filters option)         | `{}`    |
| patterns    | File patterns to match (using File.fnmatch)            | `[]`    |
| actions     | Commands to execute when files change                  | `[]`    |

### Available Variables for Commands

When specifying commands, you can use the following variables:

| Variable      | Description                              | Example                |
|---------------|------------------------------------------|------------------------|
| {{file_path}} | Full path of the changed file            | `/home/user/app/file.rb` |
| {{file_dir}}  | Directory containing the file            | `/home/user/app`        |
| {{file_name}} | File name with extension                 | `file.rb`               |
| {{file_base}} | File name without extension              | `file`                  |
| {{file_ext}}  | File extension                           | `.rb`                   |



## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/y-yagi/watchcat.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
