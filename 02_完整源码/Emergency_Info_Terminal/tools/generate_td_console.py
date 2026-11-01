"""Generate TD project files and isolated build inputs."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
NAME = "Duty_Console_B"
SHARED = ("key_events_shared.v", "uart_rx_8n1.v", "uart_tx_8n1.v",
          "buffer_ram.v", "physical_hold_buffer.v", "fat32_root_catalog.v", "fat32_sorted_catalog.v", "fat32_file_reader.v",
          "sine_quarter_rom.v", "event_manager.v", "ima_adpcm_decoder.v", "operator_permission.v",
          "operator_confirmation.v", "fat32_chain_preflight.v")


def source_list(base: Path, staged: bool):
    if staged:
        return sorted((base / "shared").glob("*.v")) + sorted(
            p for folder in ("rtl", "board", "vendor")
            for p in (base / "console" / folder).glob("*.v")
        ) + sorted((base / "vendor" / "hdmi").glob("*.v")) + sorted(
            (base / "vendor" / "sd").glob("*.v")
        )
    return [ROOT / "rtl" / name for name in SHARED] + sorted(
        p for folder in ("rtl", "board", "vendor")
        for p in (ROOT / "console" / folder).glob("*.v")
    ) + sorted((ROOT / "vendor" / "hdmi").glob("*.v")) + sorted(
        (ROOT / "vendor" / "sd").glob("*.v")
    )


def project_xml(files, adc, sdc, folder, gui):
    def rel(path):
        return Path(os.path.relpath(path, folder)).as_posix()

    def entries(paths, group, start=1):
        return "\n".join(
            f'<File Path="{escape(rel(path))}"><FileInfo>'
            f'<Attr Name="UsedInSyn" Val="true"/>'
            f'<Attr Name="UsedInP&amp;R" Val="true"/>'
            f'<Attr Name="BelongTo" Val="{group}"/>'
            f'<Attr Name="CompileOrder" Val="{index + start}"/>'
            '</FileInfo></File>'
            for index, path in enumerate(paths)
        )

    runs = '''<Runs>
      <Run Name="syn_1" Type="Synthesis" ConstraintSet="constraint_1" Active="true">
        <Strategy Name="Default_Synthesis_Strategy"/><UserParams/>
      </Run>
      <Run Name="phy_1" Type="PhysicalDesign" ConstraintSet="constraint_1" SynRun="syn_1" Active="true">
        <Strategy Name="Default_PhysicalDesign_Strategy"/><UserParams/>
      </Run></Runs><Project_Settings/>''' if gui else ""
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<Project Version="3" Minor="2">
  <Project_Created_Time/><TD_Version>6.2.168116</TD_Version><Name>{NAME}</Name>
  <HardWare><Family>EG4</Family><Device>EG4S20BG256</Device><Speed/></HardWare>
  <Source_Files>
    <Verilog>{entries(files, "design_1")}</Verilog>
    <ADC_FILE>{entries([adc], "constraint_1")}</ADC_FILE>
    <SDC_FILE>{entries([sdc], "constraint_1", 2)}</SDC_FILE>
  </Source_Files>
  <FileSets><FileSet Name="design_1" Type="DesignFiles"/><FileSet Name="constraint_1" Type="ConstrainFiles"/></FileSets>
  <TOP_MODULE><LABEL>duty_console_top</LABEL><MODULE>duty_console_top</MODULE><CREATEINDEX>user</CREATEINDEX></TOP_MODULE>
  <Property/><Device_Settings/><Configurations/>{runs}
</Project>
'''


def generate(staging, bitgen=False):
    gui = ROOT / "console" / "td"
    gui.mkdir(exist_ok=True)
    adc = ROOT / "console" / "constraints" / "hx4s20c_console.adc"
    sdc = ROOT / "console" / "constraints" / "timing_console.sdc"
    (gui / f"{NAME}.al").write_text(
        project_xml(source_list(ROOT, False), adc, sdc, gui, True), encoding="utf-8"
    )
    if staging is None:
        print(gui / f"{NAME}.al")
        return
    stage = Path(staging).resolve()
    if stage.exists():
        raise SystemExit(f"Refusing non-new staging directory: {stage}")
    (stage / "shared").mkdir(parents=True)
    for name in SHARED:
        shutil.copy2(ROOT / "rtl" / name, stage / "shared" / name)
    shutil.copytree(ROOT / "console", stage / "console", ignore=shutil.ignore_patterns("td"))
    shutil.copytree(ROOT / "vendor" / "hdmi", stage / "vendor" / "hdmi")
    shutil.copytree(ROOT / "vendor" / "sd", stage / "vendor" / "sd")
    files = source_list(stage, True)
    stage_adc = stage / "console" / "constraints" / "hx4s20c_console.adc"
    stage_sdc = stage / "console" / "constraints" / "timing_console.sdc"
    manifest = {
        str(path.relative_to(stage)).replace("\\", "/"): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in files + sorted((stage / 'console/rtl').glob('*.mem')) +
        sorted((stage / 'console/rtl').glob('*.mif')) + [stage_adc, stage_sdc]
    }
    (stage / "source_sha256.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    for kind in ("syn_1", "phy_1"):
        folder = stage / kind
        folder.mkdir()
        (folder / f"{NAME}.prj").write_text(
            project_xml(files, stage_adc, stage_sdc, folder, False), encoding="utf-8"
        )
        config = '''set ADCList {"../console/constraints/hx4s20c_console.adc"}
set SDCList {"../console/constraints/timing_console.sdc"}
set area_option -packarea
set device_name eagle_s20.db
set package_name EG4S20BG256
set prj_name Duty_Console_B
set top_model_name duty_console_top
'''
        config += (
            "set run_type syn\nset start_step read_design\nset end_step opt_gate\n"
            if kind == "syn_1" else
            "set run_type phy\nset parent ../syn_1\nset start_step opt_place\n"
            f'set end_step {"bitgen" if bitgen else "opt_route"}\n'
            "set_param place fix_hold high\n"
                                                                              
                                                                          
            "set drHoldFix on\nset arr_filter on\nset arr_rwns -100000\n"
        )
        if kind == "syn_1":
                                                                           
                                                                       
            config += "set synWildParams {gate eram_init on}\n"
        (folder / "settings.cfg").write_text(config, encoding="utf-8")
    stages = "synthesis, place, route, bitgen" if bitgen else "synthesis, place, route"
    print(f"Offline board-B build prepared: {stage}\nStages: {stages}; no programming.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--staging", type=Path)
    parser.add_argument("--bitgen", action="store_true")
    args = parser.parse_args()
    generate(args.staging, args.bitgen)
