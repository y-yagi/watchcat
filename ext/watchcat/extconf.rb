require "mkmf"
require "rb_sys/mkmf"

# Which native backend `notify` should be built with. Only relevant on macOS,
# where `notify` offers both FSEvents (the default) and kqueue; other
# platforms have a single native backend and ignore this option.
backend = ENV["WATCHCAT_BACKEND"] || with_config("backend")

unless [nil, "", "fsevent", "kqueue"].include?(backend)
  abort "unknown backend #{backend.inspect} (expected \"fsevent\" or \"kqueue\")"
end

create_rust_makefile("watchcat") do |r|
  if backend == "kqueue"
    r.features = ["macos_kqueue"]
    r.extra_cargo_args += ["--no-default-features"] # to switch off fsevent
  end
end
