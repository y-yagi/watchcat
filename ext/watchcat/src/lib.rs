use crossbeam_channel::{select, unbounded};
use magnus::{
    block::{block_given, yield_value},
    class::object,
    define_module, function, method,
    scan_args::{get_kwargs, scan_args},
    Error, Module, Object, Value,
};
use notify::{Config, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::path::Path;

#[magnus::wrap(class = "Watchcat::Watcher")]
struct WatchcatWatcher {
    tx: crossbeam_channel::Sender<bool>,
    rx: crossbeam_channel::Receiver<bool>,
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

        let (pathnames, recursive) = Self::parse_args(args)?;
        let (tx, rx) = unbounded();
        let mut watcher = RecommendedWatcher::new(tx, Config::default())
            .map_err(|e| Error::new(magnus::exception::arg_error(), e.to_string()))?;

        let mode = if recursive {
            RecursiveMode::Recursive
        } else {
            RecursiveMode::NonRecursive
        };

        for pathname in &pathnames {
            let path = Path::new(pathname);
            watcher
                .watch(path, mode)
                .map_err(|e| Error::new(magnus::exception::arg_error(), e.to_string()))?;
        }

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

                                    match yield_value::<(u8, Vec<String>), Value>(
                                        (Self::convert_event_kind(event.kind), paths)
                                    ) {
                                        Ok(_) => { continue },
                                        Err(e) => { return Err(e); }
                                    }
                                }
                                Err(e) => {
                                    return Err(
                                        Error::new(magnus::exception::runtime_error(), e.to_string())
                                    )
                                }
                            }
                        }
                        Err(e) => {
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
    fn parse_args(args: &[Value]) -> Result<(Vec<String>, bool), Error> {
        let args = scan_args(args)?;
        let (paths,): (Vec<String>,) = args.required;
        let _: () = args.optional;
        let _: () = args.splat;
        let _: () = args.trailing;
        let _: () = args.block;

        let kwargs = get_kwargs(args.keywords, &[], &["recursive"])?;
        let (recursive,): (Option<Option<bool>>,) = kwargs.optional;
        let _: () = kwargs.required;
        let _: () = kwargs.splat;

        Ok((paths, recursive.flatten().unwrap_or(false)))
    }

    fn convert_event_kind(kind: EventKind) -> u8 {
        match kind {
            EventKind::Access(_) => 1,
            EventKind::Create(_) => 2,
            EventKind::Modify(_) => 3,
            EventKind::Remove(_) => 4,
            EventKind::Other => 5,
            EventKind::Any => 99,
        }
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
