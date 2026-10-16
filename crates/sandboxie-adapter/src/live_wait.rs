//! One bounded status waiter; no event bus, callback queue or operation authority.
use std::sync::{Arc, Condvar, Mutex};
use std::time::Duration;

pub struct HealthUpdates {
    state: Mutex<(u64, bool)>,
    changed: Condvar,
}
pub struct WaitLease {
    updates: Arc<HealthUpdates>,
    sequence: u64,
}
impl HealthUpdates {
    pub fn new(sequence: u64) -> Self {
        Self {
            state: Mutex::new((sequence, false)),
            changed: Condvar::new(),
        }
    }
    pub fn publish(&self, sequence: u64) -> Result<(), &'static str> {
        self.state.lock().map_err(|_| "HEALTH_WAIT_UNAVAILABLE")?.0 = sequence;
        self.changed.notify_all();
        Ok(())
    }
    pub fn reserve(self: &Arc<Self>, sequence: u64) -> Result<WaitLease, &'static str> {
        let mut state = self.state.lock().map_err(|_| "HEALTH_WAIT_UNAVAILABLE")?;
        if state.1 {
            return Err("HEALTH_WAIT_BUSY");
        }
        state.1 = true;
        Ok(WaitLease {
            updates: self.clone(),
            sequence,
        })
    }
}
impl WaitLease {
    pub fn wait(self, timeout: Duration) -> Result<bool, &'static str> {
        let state = self
            .updates
            .state
            .lock()
            .map_err(|_| "HEALTH_WAIT_UNAVAILABLE")?;
        let (state, _) = self
            .updates
            .changed
            .wait_timeout_while(state, timeout, |value| value.0 == self.sequence)
            .map_err(|_| "HEALTH_WAIT_UNAVAILABLE")?;
        Ok(state.0 != self.sequence)
    }
}
impl Drop for WaitLease {
    fn drop(&mut self) {
        if let Ok(mut state) = self.updates.state.lock() {
            state.1 = false;
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn a_published_snapshot_before_wait_is_not_lost() {
        let updates = Arc::new(HealthUpdates::new(1));
        let lease = updates.reserve(1).unwrap();
        updates.publish(2).unwrap();
        assert!(lease.wait(Duration::from_millis(10)).unwrap());
    }
    #[test]
    fn only_one_waiter_is_reserved_and_timeout_or_drop_releases_it() {
        let updates = Arc::new(HealthUpdates::new(4));
        let lease = updates.reserve(4).unwrap();
        assert!(matches!(updates.reserve(4), Err("HEALTH_WAIT_BUSY")));
        assert!(!lease.wait(Duration::from_millis(1)).unwrap());
        drop(updates.reserve(4).unwrap());
        assert!(updates.reserve(4).is_ok());
    }
}
