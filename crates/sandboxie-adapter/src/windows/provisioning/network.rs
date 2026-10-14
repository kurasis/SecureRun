//! Synthetic loopback DNS and ICMP controls; no resolver or firewall changes.
use super::*;
use std::sync::{
    Arc,
    atomic::{AtomicBool, AtomicUsize, Ordering},
};
use windows_sys::Win32::NetworkManagement::{Dns::*, IpHelper::*};

pub(super) const SHARE_CANARY: &str = "\\\\127.0.0.1\\SecureRunP05Synthetic\\canary.txt";
pub(super) const MAPPED_CANARY: &str = "Q:\\canary.txt";
pub(super) fn share_positive(path: &str) -> bool {
    std::fs::read(path).is_ok_and(|v| v == b"SYNTHETIC_NETWORK_CANARY")
}
pub(super) fn lan_address() -> R<[u8; 4]> {
    let mut size = 0u32;
    unsafe { GetIpAddrTable(ptr::null_mut(), &mut size, 0) };
    if size == 0 || size > 65536 {
        return Err("LAN_CONTROL_ADDRESS_UNAVAILABLE");
    }
    let mut bytes = vec![0u64; (size as usize).div_ceil(8)];
    let table = bytes.as_mut_ptr() as *mut MIB_IPADDRTABLE;
    if unsafe { GetIpAddrTable(table, &mut size, 0) } != 0 {
        return Err("LAN_CONTROL_ADDRESS_UNAVAILABLE");
    }
    let count = unsafe { (*table).dwNumEntries } as usize;
    let offset = std::mem::offset_of!(MIB_IPADDRTABLE, table);
    if count > 256 || offset + count * std::mem::size_of::<MIB_IPADDRROW_XP>() > size as usize {
        return Err("LAN_CONTROL_ADDRESS_UNAVAILABLE");
    }
    let rows = unsafe {
        std::slice::from_raw_parts(
            (table as *const u8).add(offset) as *const MIB_IPADDRROW_XP,
            count,
        )
    };
    for row in rows {
        let address = row.dwAddr.to_ne_bytes();
        if address[0] != 0 && address[0] != 127 && address[0] < 224 {
            return Ok(address);
        }
    }
    Err("LAN_CONTROL_ADDRESS_UNAVAILABLE")
}
pub(super) fn raw_socket_created() -> bool {
    use windows_sys::Win32::Networking::WinSock::*;
    unsafe {
        let socket = socket(AF_INET as i32, SOCK_RAW, IPPROTO_ICMP);
        if socket == INVALID_SOCKET {
            return false;
        }
        closesocket(socket);
        true
    }
}

thread_local! { static DNS_STATUS: std::cell::Cell<i32> = const { std::cell::Cell::new(0) }; }
pub(super) fn dns_query(name: &str, cache_only: bool) -> bool {
    let name = wide(name);
    let mut servers = DNS_ADDR_ARRAY {
        MaxCount: 1,
        AddrCount: 1,
        ..Default::default()
    };
    // Microsoft DNSAsyncQuery uses a zeroed DNS_ADDR_ARRAY and an address
    // parsed without an explicit port: DNS selects its standard port 53.
    let address = [2u8, 0, 0, 0, 127, 0, 0, 1];
    for (target, value) in servers.AddrArray[0].MaxSa.iter_mut().zip(address) {
        *target = value as i8;
    }
    let request = DNS_QUERY_REQUEST {
        Version: DNS_QUERY_REQUEST_VERSION1,
        QueryName: name.as_ptr(),
        QueryType: DNS_TYPE_A,
        QueryOptions: u64::from(if cache_only {
            DNS_QUERY_CACHE_ONLY
        } else {
            DNS_QUERY_BYPASS_CACHE
                | DNS_QUERY_WIRE_ONLY
                | DNS_QUERY_NO_HOSTS_FILE
                | DNS_QUERY_NO_MULTICAST
                | DNS_QUERY_TREAT_AS_FQDN
        }),
        pDnsServerList: if cache_only {
            ptr::null_mut()
        } else {
            &mut servers
        },
        ..Default::default()
    };
    let mut result = DNS_QUERY_RESULT {
        Version: DNS_QUERY_RESULTS_VERSION1,
        ..Default::default()
    };
    let mut cancel = DNS_QUERY_CANCEL::default();
    let status = unsafe { DnsQueryEx(&request, &mut result, &mut cancel) };
    DNS_STATUS.with(|last| {
        last.set(if status != 0 {
            status
        } else {
            result.QueryStatus
        })
    });
    let passed = status == 0 && result.QueryStatus == 0 && !result.pQueryRecords.is_null();
    if !result.pQueryRecords.is_null() {
        unsafe { DnsFree(result.pQueryRecords.cast(), DnsFreeRecordList) };
    }
    passed
}

pub(super) fn icmp_echo() -> bool {
    unsafe {
        let handle = IcmpCreateFile();
        if handle == INVALID_HANDLE_VALUE {
            return false;
        }
        let mut reply = [0u64; 128];
        let count = IcmpSendEcho(
            handle,
            u32::from_ne_bytes([127, 0, 0, 1]),
            b"P05".as_ptr().cast(),
            3,
            ptr::null(),
            reply.as_mut_ptr().cast(),
            1024,
            750,
        );
        let passed = count > 0 && (*(reply.as_ptr() as *const ICMP_ECHO_REPLY)).Status == 0;
        IcmpCloseHandle(handle);
        passed
    }
}
pub(super) fn icmp_sent() -> R<u32> {
    let mut statistics = MIB_ICMP::default();
    if unsafe { GetIcmpStatistics(&mut statistics) } != 0 {
        return Err("ICMP_OBSERVER_UNAVAILABLE");
    }
    Ok(statistics.stats.icmpOutStats.dwEchos)
}

pub(super) struct DnsControl {
    count: Arc<AtomicUsize>,
    stop: Arc<AtomicBool>,
    thread: Option<std::thread::JoinHandle<()>>,
    pub(super) cache_name: String,
    pub(super) target_name: String,
}
impl DnsControl {
    pub(super) fn new(nonce: &str, metadata: &Path) -> R<Self> {
        let socket = std::net::UdpSocket::bind("127.0.0.1:53")
            .map_err(|_| "DNS_CONTROL_ENDPOINT_UNAVAILABLE")?;
        socket
            .set_read_timeout(Some(Duration::from_millis(100)))
            .map_err(|_| "DNS_CONTROL_ENDPOINT_UNAVAILABLE")?;
        let count = Arc::new(AtomicUsize::new(0));
        let stop = Arc::new(AtomicBool::new(false));
        let target_name = format!("target-{nonce}.test");
        let cache_name = format!("control-{nonce}.test");
        let expected = target_name.clone();
        let allowed = cache_name.clone();
        let counter = count.clone();
        let stopped = stop.clone();
        let thread = std::thread::spawn(move || {
            let mut bytes = [0u8; 512];
            while !stopped.load(Ordering::Relaxed) {
                let Ok((n, peer)) = socket.recv_from(&mut bytes) else {
                    continue;
                };
                if !peer.ip().is_loopback() || n < 17 || bytes[4..6] != [0, 1] {
                    continue;
                }
                let mut offset = 12;
                let mut labels = Vec::new();
                while offset < n && bytes[offset] > 0 && bytes[offset] <= 63 {
                    let length = bytes[offset] as usize;
                    offset += 1;
                    if offset + length >= n {
                        break;
                    }
                    labels
                        .push(String::from_utf8_lossy(&bytes[offset..offset + length]).to_string());
                    offset += length;
                }
                // Windows may append an EDNS OPT record. The response echoes only
                // the validated A/IN question and clears additional records.
                if offset + 5 > n || bytes[offset..offset + 5] != [0, 0, 1, 0, 1] {
                    continue;
                }
                let name = labels.join(".").to_ascii_lowercase();
                if name != expected && name != allowed {
                    continue;
                }
                let mut response = bytes[..offset + 5].to_vec();
                response[2..4].copy_from_slice(&[0x81, 0x80]);
                response[6..8].copy_from_slice(&[0, 1]);
                response[8..12].fill(0);
                response
                    .extend_from_slice(&[0xc0, 0x0c, 0, 1, 0, 1, 0, 0, 0, 30, 0, 4, 127, 0, 0, 1]);
                if socket.send_to(&response, peer).is_ok() && name == expected {
                    counter.fetch_add(1, Ordering::SeqCst);
                }
            }
        });
        let control = Self {
            count,
            stop,
            thread: Some(thread),
            cache_name,
            target_name,
        };
        if !dns_query(&control.cache_name, false) {
            let status = DNS_STATUS.with(|last| last.get());
            let data =
                serde_json::json!({"schema":1,"dns_error_hex":format!("{:08x}",status as u32)});
            std::fs::write(
                metadata.join(format!("dns-status-{nonce}.json")),
                serde_json::to_vec(&data).map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?,
            )
            .map_err(|_| "DIAGNOSTIC_JOURNAL_UNAVAILABLE")?;
            return Err("DNS_CONTROL_POSITIVE_FAILED");
        }
        if !icmp_echo() {
            return Err("ICMP_CONTROL_POSITIVE_FAILED");
        }
        Ok(control)
    }
    pub(super) fn observed(&self) -> bool {
        self.count.load(Ordering::SeqCst) > 0
    }
}
impl Drop for DnsControl {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }
}
