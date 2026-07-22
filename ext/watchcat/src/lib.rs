use crossbeam_channel::{select, unbounded};
use magnus::{
    function, method,
    scan_args::{get_kwargs, scan_args},
    Error, Module, Object, Value, Ruby
};
use notify::{Config, PollWatcher, RecommendedWatcher, RecursiveMode, Watcher};
use std::{path::Path, time::Duration, sync::{Arc, atomic::{AtomicBool, Ordering}}};

mod event;
mod gvl_helpers;
use crate::event::WatchatEvent;
use crate::gvl_helpers::{call_with_gvl, call_without_gvl};

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

// Carries a failure out of the GVL-released section without touching Ruby.
// `magnus::Error` (and the `Ruby` handle needed to build one) must only be
// used while the GVL is held, so the actual `magnus::Error` is constructed
// after control returns from `call_without_gvl`.
enum WatchFailure {
    Arg(String),
    Runtime(String),
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
        self.tx.send(true).unwrap()
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
        // `ruby` (and any `magnus::Error`/`ExceptionClass` built from it) must only be
        // touched while the GVL is held, so it is intentionally NOT captured by the
        // `call_without_gvl` closure below. Failures are carried out as plain
        // `WatchFailure` values and converted to a real `magnus::Error` afterwards,
        // once control has returned here with the GVL held again.
        let result: Result<bool, WatchFailure> = call_without_gvl(move || {
            let (tx, watcher_rx) = unbounded();
            // This variable is needed to keep `watcher` active.
            let mut _watcher = match force_polling {
                true => {
                    let delay = Duration::from_millis(poll_interval);
                    let config = notify::Config::default().with_poll_interval(delay);
                    let mut watcher = PollWatcher::new(tx, config)
                        .map_err(|e| WatchFailure::Arg(e.to_string()))?;
                    for pathname in &pathnames {
                        let path = Path::new(pathname);
                        watcher
                            .watch(path, mode)
                            .map_err(|e| WatchFailure::Arg(e.to_string()))?;
                    }
                    WatcherEnum::Poll(watcher)
                }
                false => {
                    let mut watcher = RecommendedWatcher::new(tx, Config::default())
                        .map_err(|e| WatchFailure::Arg(e.to_string()))?;
                    for pathname in &pathnames {
                        let path = Path::new(pathname);
                        watcher
                            .watch(path, mode)
                            .map_err(|e| WatchFailure::Arg(e.to_string()))?;
                    }
                    WatcherEnum::Recommended(watcher)
                }
            };

            loop {
                if terminated.load(Ordering::SeqCst) {
                    break Ok(true);
                }

                select! {
                    recv(rx) -> _res => {
                        break Ok(true);
                    }
                    recv(cmd_rx) -> cmd => {
                        if let Ok(cmd) = cmd {
                            match cmd {
                                Command::Watch(paths, recursive) => {
                                    let m = if recursive { RecursiveMode::Recursive } else { RecursiveMode::NonRecursive };
                                    for p in &paths {
                                        let _ = watcher_watch(&mut _watcher, Path::new(p), m);
                                    }
                                }
                                Command::Unwatch(paths) => {
                                    for p in &paths {
                                        let _ = watcher_unwatch(&mut _watcher, Path::new(p));
                                    }
                                }
                            }
                        }
                    }
                    recv(watcher_rx) -> res => {
                        match res {
                            Ok(event) => {
                                match event {
                                    Ok(event) => {
                                        let paths = event
                                            .paths
                                            .iter()
                                            .map(|p| p.to_string_lossy().into_owned())
                                            .collect::<Vec<_>>();

                                        if ignore_remove && matches!(event.kind, notify::event::EventKind::Remove(_)) {
                                            continue;
                                        }
                                        if ignore_access && matches!(event.kind, notify::event::EventKind::Access(_)) {
                                            continue;
                                        }
                                        if ignore_create && matches!(event.kind, notify::event::EventKind::Create(_)) {
                                            continue;
                                        }
                                        if ignore_modify && matches!(event.kind, notify::event::EventKind::Modify(_)) {
                                            continue;
                                        }

                                        // Yield to Ruby with GVL
                                        let result = call_with_gvl(|ruby| {
                                            ruby.yield_value::<(Vec<String>, Vec<String>, String), Value>(
                                                (WatchatEvent::convert_kind(&event.kind), paths, format!("{:?}", event.kind))
                                            )
                                        });

                                        if result.is_err() {
                                            break Err(WatchFailure::Runtime("Error yielding to Ruby block".to_string()));
                                        }
                                    }
                                    Err(e) => {
                                        break Err(WatchFailure::Runtime(e.to_string()));
                                    }
                                }
                            }
                            Err(e) => {
                                break Err(WatchFailure::Runtime(e.to_string()));
                            }
                        }
                    }
                }
            }
        });

        result.map_err(|err| match err {
            WatchFailure::Arg(msg) => Error::new(ruby.exception_arg_error(), msg),
            WatchFailure::Runtime(msg) => Error::new(ruby.exception_runtime_error(), msg),
        })
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

    let watcher_class = module.define_class("Watcher", ruby.class_object())?;
    watcher_class.define_singleton_method("new", function!(WatchcatWatcher::new, 0))?;
    watcher_class.define_method("watch", method!(WatchcatWatcher::watch, -1))?;
    watcher_class.define_method("close", method!(WatchcatWatcher::close, 0))?;
    watcher_class.define_method("add", method!(WatchcatWatcher::add, -1))?;
    watcher_class.define_method("unwatch", method!(WatchcatWatcher::unwatch, -1))?;

    Ok(())
}
