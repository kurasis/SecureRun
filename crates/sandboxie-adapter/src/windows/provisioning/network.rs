//! Synthetic loopback DNS and ICMP controls; no resolver or firewall changes.
use super::*;
use std::sync::{
    Arc,
    atomic::{AtomicBool, AtomicUsize, Ordering},
};
use windows_sys::Win32::NetworkManagement::{Dns::*, IpHelper::*};

pub(super) const SHARE_CANARY: &str = "\\\\127.0.0.1\\SecureRunP05Synthetic\\canary.txt";
pub(super) const MAPPED_CANARY: &str = "Q:\\canary.txt";

// Fresh boxed listeners test unsolicited incoming traffic as well as replies
// on established outbound flows. Four OS-assigned ports are the entire private
// rendezvous; neither peer supplies a remote address or executable.
pub(super) fn incoming_probe(output: &str) -> R<[bool; 4]> {
    let mut tcp = Vec::new();
    let mut udp = Vec::new();
    let mut ports = [0u16; 4];
    for (i, address) in ["127.0.0.1:0", "[::1]:0"].iter().enumerate() {
        let listener = std::net::TcpListener::bind(address).ok();
        if let Some(listener) = &listener {
            listener
                .set_nonblocking(true)
                .map_err(|_| "INCOMING_PROBE_UNAVAILABLE")?;
            ports[i] = listener
                .local_addr()
                .map_err(|_| "INCOMING_PROBE_UNAVAILABLE")?
                .port();
        }
        tcp.push(listener);
        let socket = std::net::UdpSocket::bind(address).ok();
        if let Some(socket) = &socket {
            socket
                .set_read_timeout(Some(Duration::from_millis(900)))
                .map_err(|_| "INCOMING_PROBE_UNAVAILABLE")?;
            ports[i + 2] = socket
                .local_addr()
                .map_err(|_| "INCOMING_PROBE_UNAVAILABLE")?
                .port();
        }
        udp.push(socket);
    }
    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(output)
        .map_err(|_| "INCOMING_PROBE_REPORT_UNAVAILABLE")?;
    file.write_all(&serde_json::to_vec(&ports).map_err(|_| "INCOMING_PROBE_REPORT_INVALID")?)
        .map_err(|_| "INCOMING_PROBE_REPORT_UNAVAILABLE")?;
    file.sync_all()
        .map_err(|_| "INCOMING_PROBE_REPORT_UNAVAILABLE")?;
    drop(file);
    let mut result = [false; 4];
    for (i, listener) in tcp.into_iter().enumerate() {
        let Some(listener) = listener else { continue };
        let clock = Instant::now();
        while clock.elapsed() < Duration::from_millis(1800) {
            if let Ok((mut socket, peer)) = listener.accept() {
                if peer.ip().is_loopback() {
                    let _ = socket.set_read_timeout(Some(Duration::from_millis(900)));
                    let mut bytes = [0u8; 1];
                    result[i] = socket.read_exact(&mut bytes).is_ok()
                        && bytes == *b"P"
                        && socket.write_all(b"R").is_ok();
                }
                break;
            }
            std::thread::sleep(Duration::from_millis(10));
        }
    }
    for (i, socket) in udp.into_iter().enumerate() {
        if let Some(socket) = socket {
            let mut bytes = [0u8; 1];
            if let Ok((1, peer)) = socket.recv_from(&mut bytes) {
                result[i + 2] = peer.ip().is_loopback()
                    && bytes == *b"P"
                    && socket.send_to(b"R", peer).is_ok_and(|n| n == 1);
            }
        }
    }
    Ok(result)
}

pub(super) struct IncomingControl {
    stop: Arc<AtomicBool>,
    thread: Option<std::thread::JoinHandle<R<[bool; 4]>>>,
}
impl IncomingControl {
    pub(super) fn new(root: PathBuf, leaf: String) -> Self {
        let stop = Arc::new(AtomicBool::new(false));
        let stopped = stop.clone();
        let thread = std::thread::spawn(move || {
            let clock = Instant::now();
            let ports: [u16; 4] = loop {
                if clock.elapsed() > Duration::from_secs(20) || stopped.load(Ordering::SeqCst) {
                    return Err("INCOMING_PROBE_REPORT_MISSING");
                }
                if let Ok(path) = locate_report(&root, &leaf)
                    && let Ok(mut file) = lease(&path, false)
                {
                    let mut bytes = Vec::new();
                    if Read::by_ref(&mut file)
                        .take(129)
                        .read_to_end(&mut bytes)
                        .is_ok()
                        && bytes.len() <= 128
                        && let Ok(ports) = serde_json::from_slice::<[u16; 4]>(&bytes)
                        && ports.iter().all(|port| *port == 0 || *port >= 1024)
                    {
                        break ports;
                    }
                }
                std::thread::sleep(Duration::from_millis(20));
            };
            // Exercise channels concurrently: a blocked IPv4 connect must not
            // consume the IPv6 listener's or UDP receiver's observation window.
            let jobs = ports
                .into_iter()
                .enumerate()
                .map(|(i, port)| {
                    std::thread::spawn(move || {
                        if port == 0 {
                            return false;
                        }
                        let address = if i % 2 == 0 {
                            std::net::SocketAddr::from(([127, 0, 0, 1], port))
                        } else {
                            std::net::SocketAddr::from(([0, 0, 0, 0, 0, 0, 0, 1], port))
                        };
                        let mut bytes = [0u8; 1];
                        if i < 2 {
                            let Ok(mut socket) = std::net::TcpStream::connect_timeout(
                                &address,
                                Duration::from_millis(900),
                            ) else {
                                return false;
                            };
                            let _ = socket.set_read_timeout(Some(Duration::from_millis(900)));
                            socket.write_all(b"P").is_ok()
                                && socket.read_exact(&mut bytes).is_ok()
                                && bytes == *b"R"
                        } else {
                            let bind = if i % 2 == 0 { "127.0.0.1:0" } else { "[::1]:0" };
                            let Ok(socket) = std::net::UdpSocket::bind(bind) else {
                                return false;
                            };
                            let _ = socket.set_read_timeout(Some(Duration::from_millis(1800)));
                            socket.send_to(b"P", address).is_ok()
                                && socket.recv(&mut bytes).is_ok_and(|n| n == 1)
                                && bytes == *b"R"
                        }
                    })
                })
                .collect::<Vec<_>>();
            let mut observed = [false; 4];
            for (i, job) in jobs.into_iter().enumerate() {
                observed[i] = job.join().map_err(|_| "INCOMING_OBSERVER_FAILED")?;
            }
            Ok(observed)
        });
        Self {
            stop,
            thread: Some(thread),
        }
    }
    pub(super) fn observed(mut self) -> R<[bool; 4]> {
        self.thread
            .take()
            .ok_or("INCOMING_OBSERVER_FAILED")?
            .join()
            .map_err(|_| "INCOMING_OBSERVER_FAILED")?
    }
}
impl Drop for IncomingControl {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::SeqCst);
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }
}
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
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct RawReport {
    pub(super) created: bool,
    pub(super) send_accepted: bool,
    pub(super) echo_received: bool,
}
pub(super) fn raw_echo(nonce: &str) -> RawReport {
    use windows_sys::Win32::Networking::WinSock::*;
    let mut report = RawReport {
        created: false,
        send_accepted: false,
        echo_received: false,
    };
    // Valid ICMP echo request with a unique synthetic payload. Creation of a
    // socket alone does not prove target-caused network traffic.
    let payload = format!("SecureRunP05Raw-{nonce}");
    let mut packet = vec![8u8, 0, 0, 0, 0x50, 0x05, 0, 1];
    packet.extend_from_slice(payload.as_bytes());
    let mut sum = 0u32;
    for pair in packet.chunks(2) {
        sum += u16::from_be_bytes([pair[0], *pair.get(1).unwrap_or(&0)]) as u32;
    }
    while sum > 0xffff {
        sum = (sum & 0xffff) + (sum >> 16);
    }
    packet[2..4].copy_from_slice(&(!(sum as u16)).to_be_bytes());
    unsafe {
        let socket = socket(AF_INET as i32, SOCK_RAW, IPPROTO_ICMP);
        if socket == INVALID_SOCKET {
            return report;
        }
        report.created = true;
        let timeout = 900u32;
        setsockopt(
            socket,
            SOL_SOCKET,
            SO_RCVTIMEO,
            (&timeout as *const u32).cast(),
            4,
        );
        let address = SOCKADDR_IN {
            sin_family: AF_INET,
            sin_addr: IN_ADDR {
                S_un: IN_ADDR_0 {
                    S_addr: u32::from_ne_bytes([127, 0, 0, 1]),
                },
            },
            ..Default::default()
        };
        report.send_accepted = sendto(
            socket,
            packet.as_ptr(),
            packet.len() as i32,
            0,
            (&address as *const SOCKADDR_IN).cast(),
            std::mem::size_of::<SOCKADDR_IN>() as i32,
        ) == packet.len() as i32;
        if report.send_accepted {
            let clock = Instant::now();
            let mut bytes = [0u8; 512];
            while clock.elapsed() < Duration::from_millis(950) {
                let n = recv(socket, bytes.as_mut_ptr(), bytes.len() as i32, 0);
                if n <= 0 {
                    break;
                }
                let n = n as usize;
                if n < 20 || bytes[0] >> 4 != 4 {
                    continue;
                }
                let header = (bytes[0] as usize & 15) * 4;
                if header >= 20
                    && n == header + packet.len()
                    && bytes[header..header + 2] == [0, 0]
                    && bytes[header + 4..header + 8] == packet[4..8]
                    && bytes[header + 8..n] == packet[8..]
                {
                    report.echo_received = true;
                    break;
                }
            }
        }
        closesocket(socket);
        report
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
