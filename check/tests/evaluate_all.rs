//! Every `.ncl` file in the library must link and fully evaluate. Full
//! evaluation forces every field, so contract violations in entries no scene
//! uses yet are still caught (Nickel is lazy otherwise).

use std::path::{Path, PathBuf};

use nb_nickel::{evaluate_check, evaluate_json, fs, read_params, Override};

fn lib_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap().to_path_buf()
}

fn ncl_files(dir: &Path, out: &mut Vec<PathBuf>) {
    for entry in std::fs::read_dir(dir).unwrap() {
        let path = entry.unwrap().path();
        if path.is_dir() {
            if path.file_name().map_or(false, |n| n == "check" || n == "target" || n.to_string_lossy().starts_with('.')) {
                continue;
            }
            ncl_files(&path, out);
        } else if path.extension().map_or(false, |e| e == "ncl") {
            out.push(path);
        }
    }
}

#[test]
fn every_file_evaluates() {
    let mut files = Vec::new();
    ncl_files(&lib_root(), &mut files);
    files.sort();
    assert!(!files.is_empty(), "no .ncl files found under {}", lib_root().display());
    let mut failures = Vec::new();
    for file in &files {
        // Library files may evaluate to functions, so validate without exporting.
        let result = fs::link(file).and_then(|linked| evaluate_check(&linked, &[]));
        match result {
            Ok(_) => {}
            Err(diags) => failures.push(format!(
                "{}:\n{}",
                file.strip_prefix(lib_root()).unwrap().display(),
                diags.iter().map(|d| d.render()).collect::<Vec<_>>().join("\n")
            )),
        }
    }
    assert!(failures.is_empty(), "{} file(s) failed:\n\n{}", failures.len(), failures.join("\n\n"));
    eprintln!("evaluated {} files", files.len());
}

#[test]
fn scene_has_sliders_that_apply() {
    let linked = fs::link(lib_root().join("scene.ncl")).unwrap();
    let specs = read_params(&linked).unwrap();
    let stim = specs.iter().find(|s| s.name == "stim_current").expect("stim_current slider");
    assert!(stim.min.is_some() && stim.max.is_some());
    let json = evaluate_json(&linked, &[Override::number("params.stim_current", 25.0)], Some("scene")).unwrap();
    let scene: serde_json::Value = serde_json::from_str(&json).unwrap();
    let on = &scene["neurons"][0]["stimulator_segments"][0]["stimulator"]["current_shape"]["on_current_uamps_per_square_cm"];
    assert_eq!(on.as_f64(), Some(25.0));
    assert_eq!(scene["neurons"][0]["neuron"]["segments"].as_array().unwrap().len(), 448);
}
