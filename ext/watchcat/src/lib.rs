use crossbeam_channel::{select, unbounded};
use magnus::{
    block::{block_given, yield_value},
    class::object,
    define_module, function, method,
    scan_args::{get_kwargs, scan_args},
    Error, Module, Object, Value,
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
}

#[derive(Debug)]
enum WatcherEnum {
    #[allow(dead_code)]
    Poll(PollWatcher),
    #[allow(dead_code)]
    Recommended(RecommendedWatcher),
}

impl WatchcatWatcher {
    fn new() -> Self {
        let (tx_executor, rx_executor) = unbounded::<bool>();
        Self {
            tx: tx_executor,
            rx: rx_executor,
            terminated: Arc::new(AtomicBool::new(false)),
        }
    }

    fn close(&self) {
        self.terminated.store(true, Ordering::SeqCst);
        self.tx.send(true).unwrap()
    }

    fn watch(&self, args: &[Value]) -> Result<bool, Error> {
        if !block_given() {
            return Err(Error::new(magnus::exception::arg_error(), "no block given"));
        }

    let (pathnames, recursive, force_polling, poll_interval, ignore_remove, ignore_access, ignore_create, ignore_modify) = Self::parse_args(args)?;
        let mode = if recursive {
            RecursiveMode::Recursive
        } else {
            RecursiveMode::NonRecursive
        };

        let terminated = self.terminated.clone();
        let rx_clone = self.rx.clone();

        Self::watch_threaded(
            pathnames, mode, force_polling, poll_interval, ignore_remove, ignore_access, ignore_create, ignore_modify, terminated, rx_clone
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
        rx: crossbeam_channel::Receiver<bool>
    ) -> Result<bool, Error> {
        call_without_gvl(move || {
            let (tx, watcher_rx) = unbounded();
            // This variable is needed to keep `watcher` active.
            let _watcher = match force_polling {
                true => {
                    let delay = Duration::from_millis(poll_interval);
                    let config = notify::Config::default().with_poll_interval(delay);
                    let mut watcher = PollWatcher::new(tx, config)
                        .map_err(|e| Error::new(magnus::exception::arg_error(), e.to_string()))?;
                    for pathname in &pathnames {
                        let path = Path::new(pathname);
                        watcher
                            .watch(path, mode)
                            .map_err(|e| Error::new(magnus::exception::arg_error(), e.to_string()))?;
                    }
                    WatcherEnum::Poll(watcher)
                }
                false => {
                    let mut watcher = RecommendedWatcher::new(tx, Config::default())
                        .map_err(|e| Error::new(magnus::exception::arg_error(), e.to_string()))?;
                    for pathname in &pathnames {
                        let path = Path::new(pathname);
                        watcher
                            .watch(path, mode)
                            .map_err(|e| Error::new(magnus::exception::arg_error(), e.to_string()))?;
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
                                        let result = call_with_gvl(|_| {
                                            yield_value::<(Vec<String>, Vec<String>, String), Value>(
                                                (WatchatEvent::convert_kind(&event.kind), paths, format!("{:?}", event.kind))
                                            )
                                        });

                                        if result.is_err() {
                                            break Err(Error::new(magnus::exception::runtime_error(), "Error yielding to Ruby block"));
                                        }
                                    }
                                    Err(e) => {
                                        break Err(Error::new(magnus::exception::runtime_error(), e.to_string()));
                                    }
                                }
                            }
                            Err(e) => {
                                break Err(Error::new(magnus::exception::runtime_error(), e.to_string()));
                            }
                        }
                    }
                }
            }
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
}

#[magnus::init]
fn init() -> Result<(), Error> {
    let module = define_module("Watchcat")?;

    let watcher_class = module.define_class("Watcher", object())?;
    watcher_class.define_singleton_method("new", function!(WatchcatWatcher::new, 0))?;
    watcher_class.define_method("watch", method!(WatchcatWatcher::watch, -1))?;
    watcher_class.define_method("close", method!(WatchcatWatcher::close, 0))?;

    Ok(())
}
