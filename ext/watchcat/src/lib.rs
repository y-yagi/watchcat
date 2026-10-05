use crossbeam_channel::{bounded, select, unbounded};
use magnus::{
    function, method,
    scan_args::{get_kwargs, scan_args},
    value::ReprValue,
    Error, Module, Object, RModule, Value, Ruby
};
use notify::{Config, PollWatcher, RecommendedWatcher, RecursiveMode, Watcher, WatcherKind};
use std::{path::Path, time::Duration, sync::{Arc, atomic::{AtomicBool, Ordering}}};

mod event;
mod gvl_helpers;
use crate::event::WatchatEvent;
use crate::gvl_helpers::{call_with_gvl, call_without_gvl, check_interrupts};

fn backend() -> String {
    match RecommendedWatcher::kind() {
        WatcherKind::Inotify => "inotify",
        WatcherKind::Fsevent => "fsevent",
        WatcherKind::Kqueue => "kqueue",
        WatcherKind::ReadDirectoryChangesWatcher => "ReadDirectoryChanges",
        WatcherKind::PollWatcher => "poll",
        _ => "unknown",
    }
    .to_string()
}

#[magnus::wrap(class = "Watchcat::Watcher")]
struct WatchcatWatcher {
    tx: crossbeam_channel::Sender<bool>,
    rx: crossbeam_channel::Receiver<bool>,
    terminated: Arc<AtomicBool>,
    cmd_tx: crossbeam_channel::Sender<Command>,
    cmd_rx: crossbeam_channel::Receiver<Command>,
}

#[derive(Debug)]
enum WatcherEnum {
    Poll(PollWatcher),
    Recommended(RecommendedWatcher),
}

fn watcher_watch(w: &mut WatcherEnum, path: &Path, mode: RecursiveMode) -> notify::Result<()> {
    match w {
        WatcherEnum::Poll(x) => x.watch(path, mode),
        WatcherEnum::Recommended(x) => x.watch(path, mode),
    }
}

fn watcher_unwatch(w: &mut WatcherEnum, path: &Path) -> notify::Result<()> {
    match w {
        WatcherEnum::Poll(x) => x.unwatch(path),
        WatcherEnum::Recommended(x) => x.unwatch(path),
    }
}

fn log_error(message: String) {
    call_with_gvl(|ruby| {
        let _ = call_logger(&ruby, message);
    });
}

fn call_logger(ruby: &Ruby, message: String) -> Result<(), Error> {
    let logger: Value = ruby
        .class_object()
        .const_get::<_, RModule>("Watchcat")?
        .funcall("logger", ())?;
    logger.funcall::<_, _, Value>("error", (message,))?;
    Ok(())
}

enum WaitResult {
    Stopped,
    Event(notify::Event),
    NotifyError(String),
    Failure(String),
    Interrupted,
}

fn create_watcher(
    pathnames: &[String],
    mode: RecursiveMode,
    force_polling: bool,
    poll_interval: u64,
    tx: crossbeam_channel::Sender<notify::Result<notify::Event>>,
) -> notify::Result<WatcherEnum> {
    let mut watcher = if force_polling {
        let delay = Duration::from_millis(poll_interval);
        let config = notify::Config::default().with_poll_interval(delay);
        WatcherEnum::Poll(PollWatcher::new(tx, config)?)
    } else {
        WatcherEnum::Recommended(RecommendedWatcher::new(tx, Config::default())?)
    };
    for pathname in pathnames {
        watcher_watch(&mut watcher, Path::new(pathname), mode)?;
    }
    Ok(watcher)
}

enum Command {
    Watch(Vec<String>, bool),   // paths, recursive
    Unwatch(Vec<String>),       // paths
}

impl WatchcatWatcher {
    fn new() -> Self {
        let (tx_executor, rx_executor) = unbounded::<bool>();
        let (cmd_tx, cmd_rx) = unbounded::<Command>();
        Self {
            tx: tx_executor,
            rx: rx_executor,
            terminated: Arc::new(AtomicBool::new(false)),
            cmd_tx,
            cmd_rx,
        }
    }

    fn close(&self) {
        self.terminated.store(true, Ordering::SeqCst);
        // See `add`/`unwatch`: `send` cannot fail while `self` retains `rx`,
        // but `.unwrap()` would still turn a hypothetical failure into a
        // Rust panic, and a panic crossing the FFI boundary aborts the whole
        // process instead of raising in Ruby. Not worth the risk for a
        // result we already know.
        let _ = self.tx.send(true);
    }

    fn watch(&self, args: &[Value]) -> Result<bool, Error> {
        let ruby = unsafe { Ruby::get_unchecked() };
        let ruby_ref = &ruby;
        if !ruby_ref.block_given() {
            return Err(Error::new(ruby_ref.exception_arg_error(), "no block given"));
        }

        let (pathnames, recursive, force_polling, poll_interval, ignore_remove, ignore_access, ignore_create, ignore_modify) = Self::parse_args(args)?;
        let mode = if recursive {
            RecursiveMode::Recursive
        } else {
            RecursiveMode::NonRecursive
        };

        let terminated = self.terminated.clone();
        let rx_clone = self.rx.clone();
        let cmd_rx = self.cmd_rx.clone();

        Self::watch_threaded(
            pathnames, mode, force_polling, poll_interval, ignore_remove, ignore_access, ignore_create, ignore_modify, terminated, rx_clone, cmd_rx, ruby_ref
        )
    }

    #[allow(clippy::too_many_arguments)]
    fn watch_threaded(
        pathnames: Vec<String>,
        mode: RecursiveMode,
        force_polling: bool,
        poll_interval: u64,
        ignore_remove: bool,
        ignore_access: bool,
        ignore_create: bool,
        ignore_modify: bool,
        terminated: Arc<AtomicBool>,
        rx: crossbeam_channel::Receiver<bool>,
        cmd_rx: crossbeam_channel::Receiver<Command>,
        ruby: &Ruby
    ) -> Result<bool, Error> {
        // `ruby` (and any `magnus::Error`/`Value` built from it) must only be
        // touched while the GVL is held, so it is intentionally NOT captured by
        // the `call_without_gvl` closures below. They hand plain Rust values back
        // as `WaitResult`, and anything that involves Ruby (yielding to the
        // block, raising, handling interrupts) happens here with the GVL held.
        let (interrupt_tx, interrupt_rx) = bounded::<()>(1);
        let (tx, watcher_rx) = unbounded();

        // This variable is needed to keep `watcher` active.
        let mut _watcher = loop {
            let tx = tx.clone();
            match call_without_gvl(
                || create_watcher(&pathnames, mode, force_polling, poll_interval, tx),
                &interrupt_tx,
            ) {
                Some(result) => {
                    break result.map_err(|e| Error::new(ruby.exception_arg_error(), e.to_string()))?
                }
                None => check_interrupts()?,
            }
        };
        drop(tx);

        let mut logged_notify_errors = std::collections::HashSet::<String>::new();

        loop {
            let outcome = call_without_gvl(
                || loop {
                    if terminated.load(Ordering::SeqCst) {
                        break WaitResult::Stopped;
                    }

                    select! {
                        recv(interrupt_rx) -> _res => {
                            break WaitResult::Interrupted;
                        }
                        recv(rx) -> _res => {
                            break WaitResult::Stopped;
                        }
                        recv(cmd_rx) -> cmd => {
                            if let Ok(cmd) = cmd {
                                match cmd {
                                    Command::Watch(paths, recursive) => {
                                        let m = if recursive { RecursiveMode::Recursive } else { RecursiveMode::NonRecursive };
                                        for p in &paths {
                                            if let Err(e) = watcher_watch(&mut _watcher, Path::new(p), m) {
                                                log_error(format!("watchcat: failed to watch {p}: {e}"));
                                            }
                                        }
                                    }
                                    Command::Unwatch(paths) => {
                                        for p in &paths {
                                            if let Err(e) = watcher_unwatch(&mut _watcher, Path::new(p)) {
                                                log_error(format!("watchcat: failed to unwatch {p}: {e}"));
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        recv(watcher_rx) -> res => {
                            match res {
                                Ok(Ok(event)) => {
                                    if ignore_remove && matches!(event.kind, notify::event::EventKind::Remove(_)) {
                                        continue;
                                    }

                                    // With `macos_kqueue`, every chmod/chown/touch on macOS
                                    // arrives as `Metadata(Any)` too, but kqueue has no
                                    // separate `Access` events to conflate it with, so it
                                    // must not be swallowed by `ignore_access` there.
                                    let macos_ambiguous_metadata_touch = cfg!(all(target_os = "macos", not(feature = "macos_kqueue")))
                                        && matches!(
                                            event.kind,
                                            notify::event::EventKind::Modify(
                                                notify::event::ModifyKind::Metadata(
                                                    notify::event::MetadataKind::Any
                                                )
                                            )
                                        );
                                    if ignore_access
                                        && (matches!(
                                            event.kind,
                                            notify::event::EventKind::Access(_)
                                        ) || macos_ambiguous_metadata_touch)
                                    {
                                        continue;
                                    }
                                    if ignore_create && matches!(event.kind, notify::event::EventKind::Create(_)) {
                                        continue;
                                    }
                                    if ignore_modify && matches!(event.kind, notify::event::EventKind::Modify(_)) {
                                        continue;
                                    }

                                    break WaitResult::Event(event);
                                }
                                Ok(Err(e)) => {
                                    break WaitResult::NotifyError(e.to_string());
                                }
                                Err(e) => {
                                    break WaitResult::Failure(e.to_string());
                                }
                            }
                        }
                    }
                },
                &interrupt_tx,
            )
            .unwrap_or(WaitResult::Interrupted);

            match outcome {
                WaitResult::Stopped => return Ok(true),
                WaitResult::Event(event) => {
                    let paths = event
                        .paths
                        .iter()
                        .map(|p| p.to_string_lossy().into_owned())
                        .collect::<Vec<_>>();
                    ruby.yield_value::<(Vec<String>, Vec<String>, String), Value>(
                        (WatchatEvent::convert_kind(&event.kind), paths, format!("{:?}", event.kind))
                    )?;
                }
                WaitResult::NotifyError(msg) => {
                    if logged_notify_errors.insert(msg.clone()) {
                        call_logger(ruby, format!("watchcat: {msg}"))?;
                    }
                }
                WaitResult::Failure(msg) => return Err(Error::new(ruby.exception_runtime_error(), msg)),
                WaitResult::Interrupted => check_interrupts()?,
            }
        }
    }

    #[allow(clippy::let_unit_value, clippy::type_complexity)]
    fn parse_args(args: &[Value]) -> Result<(Vec<String>, bool, bool, u64, bool, bool, bool, bool), Error> {
        type KwArgBool = Option<Option<bool>>;
        type KwArgU64 = Option<Option<u64>>;

        let args = scan_args(args)?;
        let (paths,): (Vec<String>,) = args.required;
        let _: () = args.optional;
        let _: () = args.splat;
        let _: () = args.trailing;
        let _: () = args.block;

        let kwargs = get_kwargs(
            args.keywords,
            &[],
            &["recursive", "force_polling", "poll_interval", "ignore_remove", "ignore_access", "ignore_create", "ignore_modify"],
        )?;
        let (recursive, force_polling, poll_interval, ignore_remove, ignore_access, ignore_create, ignore_modify): (KwArgBool, KwArgBool, KwArgU64, KwArgBool, KwArgBool, KwArgBool, KwArgBool) =
            kwargs.optional;
        let _: () = kwargs.required;
        let _: () = kwargs.splat;

        Ok((
            paths,
            recursive.flatten().unwrap_or(false),
            force_polling.flatten().unwrap_or(false),
            poll_interval.flatten().unwrap_or(200),
            ignore_remove.flatten().unwrap_or(false),
            ignore_access.flatten().unwrap_or(false),
            ignore_create.flatten().unwrap_or(false),
            ignore_modify.flatten().unwrap_or(false),
        ))
    }

    fn add(&self, args: &[Value]) -> Result<bool, Error> {
        let (paths, recursive) = Self::parse_add_args(args)?;
        // `send` only fails when every receiver is disconnected, but `self`
        // holds `cmd_rx` for the whole lifetime of this object, so it cannot
        // fail here. If the watch loop has already stopped, the command is
        // simply buffered and never applied (a harmless no-op).
        let _ = self.cmd_tx.send(Command::Watch(paths, recursive));
        Ok(true)
    }

    fn unwatch(&self, args: &[Value]) -> Result<bool, Error> {
        let paths = Self::parse_unwatch_args(args)?;
        // See `add`: `send` cannot fail while `self` retains `cmd_rx`.
        let _ = self.cmd_tx.send(Command::Unwatch(paths));
        Ok(true)
    }

    #[allow(clippy::let_unit_value)]
    fn parse_add_args(args: &[Value]) -> Result<(Vec<String>, bool), Error> {
        type KwArgBool = Option<Option<bool>>;

        let args = scan_args(args)?;
        let (paths,): (Vec<String>,) = args.required;
        let _: () = args.optional;
        let _: () = args.splat;
        let _: () = args.trailing;
        let _: () = args.block;

        let kwargs = get_kwargs(args.keywords, &[], &["recursive"])?;
        let (recursive,): (KwArgBool,) = kwargs.optional;
        let _: () = kwargs.required;
        let _: () = kwargs.splat;

        Ok((paths, recursive.flatten().unwrap_or(true)))
    }

    #[allow(clippy::let_unit_value)]
    fn parse_unwatch_args(args: &[Value]) -> Result<Vec<String>, Error> {
        let args = scan_args(args)?;
        let (paths,): (Vec<String>,) = args.required;
        let _: () = args.optional;
        let _: () = args.splat;
        let _: () = args.trailing;
        let _: () = args.block;

        let kwargs = get_kwargs::<&str, (), (), ()>(args.keywords, &[], &[])?;
        let _: () = kwargs.optional;
        let _: () = kwargs.required;
        let _: () = kwargs.splat;

        Ok(paths)
    }
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("Watchcat")?;
    module.define_singleton_method("backend", function!(backend, 0))?;

    let watcher_class = module.define_class("Watcher", ruby.class_object())?;
    watcher_class.define_singleton_method("new", function!(WatchcatWatcher::new, 0))?;
    watcher_class.define_method("watch", method!(WatchcatWatcher::watch, -1))?;
    watcher_class.define_method("close", method!(WatchcatWatcher::close, 0))?;
    watcher_class.define_method("add", method!(WatchcatWatcher::add, -1))?;
    watcher_class.define_method("unwatch", method!(WatchcatWatcher::unwatch, -1))?;

    Ok(())
}
