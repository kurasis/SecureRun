//! Disposable lab helper: prints the production-compiled box section for a
//! synthetic mandatory scope so an isolated experiment can reuse it exactly.
//! Never a product command; it performs no engine or file-system effects.
use securerun_sandboxie_adapter::policy::{DesiredPolicy, Mandatory, Preset, compile};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let result = (|| -> Result<String, &'static str> {
        let [_, preset, root, metadata, code, sibling, marker] = args.as_slice() else {
            return Err("USAGE: preset root metadata code sibling marker");
        };
        let preset = match preset.as_str() {
            "STANDARD_OFFLINE" => Preset::StandardOffline,
            "STANDARD_ONLINE" => Preset::StandardOnline,
            _ => return Err("PRESET_UNSUPPORTED"),
        };
        let desired = DesiredPolicy {
            preset,
            ..DesiredPolicy::default()
        };
        let mandatory = Mandatory {
            root: root.clone(),
            metadata: metadata.clone(),
            code: code.clone(),
            siblings: vec![sibling.clone()],
            marker: marker.clone(),
        };
        let compiled = compile(&desired, &mandatory)?;
        serde_json::to_string(&compiled.section).map_err(|_| "SECTION_ENCODING_FAILED")
    })();
    match result {
        Ok(section) => println!("{section}"),
        Err(code) => {
            eprintln!("{code}");
            std::process::exit(2);
        }
    }
}
