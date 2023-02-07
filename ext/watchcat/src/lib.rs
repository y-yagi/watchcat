use crossbeam_channel::{select, unbounded};
use magnus::{
    block::{block_given, yield_value},
    class::object,
    define_module, function, gvl, method,
    scan_args::{get_kwargs, scan_args},
    Error, Module, Object, Value,
};
use notify::{Config, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::path::Path;

#[magnus::wrap(class = "Watchcat::Event")]
struct Event {
    kind: u8,
    paths: Vec<String>,
}

impl Event {
    fn new(kind: u8, paths: Vec<String>) -> Self {
        Self { kind, paths }
    }

    fn kind(&self) -> u8 {
        self.kind
    }

    fn paths(&self) -> Vec<String> {
        self.paths.to_vec()
    }
}

#[magnus::wrap(class = "Watchcat::Executor")]
struct Executor {
    tx: crossbeam_channel::Sender<bool>,
    rx: crossbeam_channel::Receiver<bool>,
}

impl Executor {
    fn new() -> Self {
        let (tx_executor, rx_executor) = unbounded::<bool>();
        Self {
            tx: tx_executor,
            rx: rx_executor,
        }
    }

    fn close(&self) {
        self.tx.send(true);
    }

    fn watch(&self, args: &[Value]) -> Result<String, Error> {
        if !block_given() {
            return Err(Error::new(magnus::exception::arg_error(), "no block given"));
        }

        let (pathname, recursive) = Self::parse_args(args)?;
        let path = Path::new(&pathname);
        let (tx, rx) = unbounded();
        let mut watcher = match RecommendedWatcher::new(tx, Config::default()) {
            Ok(w) => w,
            Err(error) => {
                return Err(Error::new(
                    magnus::exception::arg_error(),
                    error.to_string(),
                ))
            }
        };

        let mode = if recursive {
            RecursiveMode::Recursive
        } else {
            RecursiveMode::NonRecursive
        };

        match watcher.watch(path, mode) {
            Ok(_result) => {}
            Err(error) => {
                return Err(Error::new(
                    magnus::exception::arg_error(),
                    error.to_string(),
                ))
            }
        }

        gvl::without_gvl(
            move |_| loop {
                select! {
                    recv(self.rx) -> _res => {
                        eprintln!("get self.rx");
                        return
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

                                        match yield_value::<Event, Value>(Event {
                                            kind: (Self::convert_event_kind(event.kind)),
                                            paths: paths,
                                        }) {
                                            Ok(_) => {},
                                            Err(e) => {
                                                eprintln!("yield error: {:?}", e);
                                                panic!();
                                            }
                                        }
                                    }
                                    Err(e) => {
                                        eprintln!("got unexpected event error: {:?}", e);
                                        return
                                    }
                                }
                            }
                            Err(e) => eprintln!("got unexpected response error: {:?}", e),
                        }
                    }
                }
            },
            Some(|| {
                panic!();
            }),
        );
        return Ok("".to_string());
    }

    fn parse_args(args: &[Value]) -> Result<(String, bool), Error> {
        let args = scan_args(args)?;
        let (path,): (String,) = args.required;
        let _: () = args.optional;
        let _: () = args.splat;
        let _: () = args.trailing;
        let _: () = args.block;

        let kwargs = get_kwargs(args.keywords, &[], &["recursive"])?;
        let (recursive,): (Option<Option<bool>>,) = kwargs.optional;
        let _: () = kwargs.required;
        let _: () = kwargs.splat;

        Ok((path, recursive.flatten().unwrap_or_else(|| false)))
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

    let executor_class = module.define_class("Executor", object())?;
    executor_class.define_singleton_method("new", function!(Executor::new, 0))?;
    executor_class.define_method("raw_watch", method!(Executor::watch, -1))?;
    executor_class.define_method("raw_close", method!(Executor::close, 0))?;

    let event_class = module.define_class("Event", object())?;
    event_class.define_singleton_method("new", function!(Event::new, 2))?;
    event_class.define_method("kind", method!(Event::kind, 0))?;
    event_class.define_method("paths", method!(Event::paths, 0))?;

    Ok(())
}
