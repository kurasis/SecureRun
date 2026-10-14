use crate::*;
use std::{collections::HashMap, path::PathBuf};
use uuid::Uuid;

pub struct BoundSelection {
    pub id: Uuid,
    pub operation_id: Uuid,
    pub environment_id: Uuid,
    pub generation: u64,
    pub revision: u64,
    pub purpose: SelectionPurpose,
    pub caller_label: String,
    pub expires_at: u64,
    pub path: PathBuf,
    pub identity: FileIdentity,
}
#[derive(Default)]
pub struct Selections {
    entries: HashMap<Uuid, BoundSelection>,
}
impl Selections {
    pub fn insert(&mut self, selection: BoundSelection) -> Uuid {
        let id = selection.id;
        self.entries.insert(id, selection);
        id
    }
    pub fn consume(
        &mut self,
        id: Uuid,
        operation: &Operation,
        purpose: SelectionPurpose,
        caller: &str,
        now: u64,
    ) -> Result<BoundSelection> {
        let item = self
            .entries
            .get(&id)
            .ok_or_else(|| AppError::new(ErrorCode::SelectionScopeMismatch))?;
        if now >= item.expires_at {
            self.entries.remove(&id);
            return err(ErrorCode::SelectionExpired);
        }
        if item.operation_id != operation.id
            || item.environment_id != operation.environment_id
            || item.generation != operation.environment_generation
            || item.revision != operation.requested_revision
            || item.purpose != purpose
            || item.caller_label != caller
        {
            return err(ErrorCode::SelectionScopeMismatch);
        }
        Ok(self.entries.remove(&id).unwrap())
    }
    pub fn invalidate_environment(&mut self, environment_id: Uuid) {
        self.entries
            .retain(|_, item| item.environment_id != environment_id);
    }
}
