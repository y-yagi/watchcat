use crossbeam_channel::{select, unbounded};
use magnus::{
    block::{block_given, yield_value},
    class::object,
    define_module, function, method,
    scan_args::{get_kwargs, scan_args},
    Error, Module, Object, Value,
};
use notify::{
    event::{
        AccessKind, AccessMode, CreateKind, DataChange, MetadataKind, ModifyKind, RemoveKind,
        RenameMode,
    },
    Config, EventKind, PollWatcher, RecommendedWatcher, RecursiveMode, Watcher,
};
use std::{path::Path, time::Duration};

#[magnus::wrap(class = "Watchcat::Watcher")]
struct WatchcatWatcher {
    tx: crossbeam_channel::Sender<bool>,
    rx: crossbeam_channel::Receiver<bool>,
}

#[derive(Debug)]
enum WatcherEnum {
    Poll(PollWatcher),
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

                                    yield_value::<(Vec<String>, Vec<String>, String), Value>(
                                        (Self::convert_event_kind(&event.kind), paths, format!("{:?}", event.kind))
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
        let args = scan_args(args)?;
        let (paths,): (Vec<String>,) = args.required;
        let _: () = args.optional;
        let _: () = args.splat;
        let _: () = args.trailing;
        let _: () = args.block;

        let kwargs = get_kwargs(args.keywords, &[], &["recursive", "force_polling", "poll_interval"])?;
        let (recursive, force_polling, poll_interval): (Option<Option<bool>>, Option<Option<bool>>, Option<Option<u64>>) =
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

    fn convert_event_kind(kind: &EventKind) -> Vec<String> {
        let mut kinds = Vec::new();

        match kind {
            EventKind::Access(access_kind) => {
                kinds.push("access".to_string());
                match access_kind {
                    AccessKind::Read => {
                        kinds.push("read".to_string());
                    }
                    AccessKind::Open(access_mode) => {
                        kinds.push("open".to_string());
                        match access_mode {
                            AccessMode::Execute => {
                                kinds.push("execute".to_string());
                            }
                            AccessMode::Read => {
                                kinds.push("read".to_string());
                            }
                            AccessMode::Write => {
                                kinds.push("write".to_string());
                            }
                            _ => {}
                        }
                    }
                    AccessKind::Close(access_mode) => {
                        kinds.push("close".to_string());
                        match access_mode {
                            AccessMode::Execute => {
                                kinds.push("execute".to_string());
                            }
                            AccessMode::Read => {
                                kinds.push("read".to_string());
                            }
                            AccessMode::Write => {
                                kinds.push("write".to_string());
                            }
                            _ => {}
                        }
                    }
                    _ => {}
                }
            }
            EventKind::Create(create_kind) => {
                kinds.push("create".to_string());
                match create_kind {
                    CreateKind::File => kinds.push("file".to_string()),
                    CreateKind::Folder => kinds.push("folder".to_string()),
                    _ => {}
                }
            }
            EventKind::Modify(modify_kind) => {
                kinds.push("modify".to_string());
                match modify_kind {
                    ModifyKind::Data(data_change) => {
                        kinds.push("data_change".to_string());
                        match data_change {
                            DataChange::Size => kinds.push("size".to_string()),
                            DataChange::Content => kinds.push("content".to_string()),
                            _ => {}
                        }
                    }
                    ModifyKind::Metadata(metadata_kind) => {
                        kinds.push("metadata".to_string());
                        match metadata_kind {
                            MetadataKind::AccessTime => kinds.push("access_time".to_string()),
                            MetadataKind::WriteTime => kinds.push("write_time".to_string()),
                            MetadataKind::Permissions => kinds.push("permissions".to_string()),
                            MetadataKind::Ownership => kinds.push("ownership".to_string()),
                            MetadataKind::Extended => kinds.push("extended".to_string()),
                            _ => {}
                        }
                    }
                    ModifyKind::Name(rename_mode) => {
                        kinds.push("rename".to_string());
                        match rename_mode {
                            RenameMode::From => kinds.push("from".to_string()),
                            RenameMode::To => kinds.push("to".to_string()),
                            RenameMode::Both => kinds.push("both".to_string()),
                            _ => {}
                        }
                    }
                    _ => {}
                }
            }
            EventKind::Remove(remove_kind) => {
                kinds.push("remove".to_string());
                match remove_kind {
                    RemoveKind::File => kinds.push("file".to_string()),
                    RemoveKind::Folder => kinds.push("folder".to_string()),
                    _ => {}
                }
            }
            _ => {}
        }

        kinds
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
