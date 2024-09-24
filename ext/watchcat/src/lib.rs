use crossbeam_channel::{select, unbounded};
use magnus::{
    block::{block_given, yield_value},
    class::object,
    define_module, function, method,
    scan_args::{get_kwargs, scan_args},
    Error, Module, Object, Value,
};
use notify::{Config, PollWatcher, RecommendedWatcher, RecursiveMode, Watcher};
use std::{path::Path, time::Duration};

mod event;
use crate::event::WatchatEvent;

#[magnus::wrap(class = "Watchcat::Watcher")]
struct WatchcatWatcher {
    tx: crossbeam_channel::Sender<bool>,
    rx: crossbeam_channel::Receiver<bool>,
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
        }
    }

    fn close(&self) {
        self.tx.send(true).unwrap()
    }

    fn watch(&self, args: &[Value]) -> Result<bool, Error> {
        if !block_given() {
            return Err(Error::new(magnus::exception::arg_error(), "no block given"));
        }

        let (pathnames, recursive, force_polling, poll_interval) = Self::parse_args(args)?;
        let (tx, rx) = unbounded();
        let mode = if recursive {
            RecursiveMode::Recursive
        } else {
            RecursiveMode::NonRecursive
        };

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
            select! {
                recv(self.rx) -> _res => {
                    return Ok(true)
                }
                recv(rx) -> res => {
                    match res {
                        Ok(event) => {
                            match event {
                                Ok(event) => {
                                    let paths = event
                                        .paths
                                        .iter()
                                        .map(|p| p.to_string_lossy().into_owned())
                                        .collect::<Vec<_>>();
                                    println!("DEBUG: {:?}", event);
                                    yield_value::<(Vec<String>, Vec<String>, String), Value>(
                                        (WatchatEvent::convert_kind(&event.kind), paths, format!("{:?}", event.kind))
                                    )?;
                                }
                                Err(e) => {
                                    return Err(
                                        Error::new(magnus::exception::runtime_error(), e.to_string())
                                    )
                                }
                            }
                        }
                        Err(e) => {
                            println!("DEBUG(err): {:?}", e);
                            return Err(
                                Error::new(magnus::exception::runtime_error(), e.to_string())
                            )
                        }
                    }
                }
            }
        }
    }

    #[allow(clippy::let_unit_value)]
    fn parse_args(args: &[Value]) -> Result<(Vec<String>, bool, bool, u64), Error> {
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
            &["recursive", "force_polling", "poll_interval"],
        )?;
        let (recursive, force_polling, poll_interval): (KwArgBool, KwArgBool, KwArgU64) =
            kwargs.optional;
        let _: () = kwargs.required;
        let _: () = kwargs.splat;

        Ok((
            paths,
            recursive.flatten().unwrap_or(false),
            force_polling.flatten().unwrap_or(false),
            poll_interval.flatten().unwrap_or(200),
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
