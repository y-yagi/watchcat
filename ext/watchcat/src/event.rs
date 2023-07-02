use notify::{
    event::{
        AccessKind, AccessMode, CreateKind, DataChange, MetadataKind, ModifyKind, RemoveKind,
        RenameMode,
    },
    EventKind,
};

#[derive(Debug)]
pub enum WatchatEvent {}

impl WatchatEvent {
    pub fn convert_kind(kind: &EventKind) -> Vec<String> {
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
