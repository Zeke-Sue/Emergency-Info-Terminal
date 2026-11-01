"""Generate TD project files and isolated build inputs."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
NAME = "Emergency_Info_Terminal"

def file_list(root):
    files = sorted(p for folder in ("rtl", "board", "vendor")
                   for p in (root/folder).rglob("*.v")
                   if p.name not in ("global_def.v", "audio_permission_probe.v"))
    return files + [root/'console/rtl'/name for name in
                    ('wav_stream_parser.v', 'wav_canonical_pcm_parser.v')]

def asset_list(root):
    return sorted(list((root/'rtl').glob('*.mem'))+
                  list((root/'rtl').glob('*.mif')))

def project_xml(root, folder, gui):
    def rel(p):
        import os
        return Path(os.path.relpath(p, folder)).as_posix()
    def entries(files, group, start=1):
        return "\n".join(
            f'<File Path="{escape(rel(p))}"><FileInfo>'
            f'<Attr Name="UsedInSyn" Val="true"/>'
            f'<Attr Name="UsedInP&amp;R" Val="true"/>'
            f'<Attr Name="BelongTo" Val="{group}"/>'
            f'<Attr Name="CompileOrder" Val="{i+start}"/>'
            '</FileInfo></File>' for i, p in enumerate(files))
    runs = '''<Runs>
      <Run Name="syn_1" Type="Synthesis" ConstraintSet="constraint_1" Active="true">
        <Strategy Name="Default_Synthesis_Strategy"/><UserParams/>
      </Run>
      <Run Name="phy_1" Type="PhysicalDesign" ConstraintSet="constraint_1" SynRun="syn_1" Active="true">
        <Strategy Name="Default_PhysicalDesign_Strategy"/><UserParams/>
      </Run></Runs><Project_Settings/>''' if gui else ''
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<Project Version="3" Minor="2">
  <Project_Created_Time/><TD_Version>6.2.168116</TD_Version><Name>{NAME}</Name>
  <HardWare><Family>EG4</Family><Device>EG4S20BG256</Device><Speed/></HardWare>
  <Source_Files>
    <Verilog>{entries(file_list(root), 'design_1')}</Verilog>
    <ADC_FILE>{entries([root/'constraints/hx4s20c.adc'], 'constraint_1')}</ADC_FILE>
    <SDC_FILE>{entries([root/'constraints/timing.sdc'], 'constraint_1', 2)}</SDC_FILE>
  </Source_Files>
  <FileSets><FileSet Name="design_1" Type="DesignFiles"/><FileSet Name="constraint_1" Type="ConstrainFiles"/></FileSets>
  <TOP_MODULE><LABEL>hdmi_player_top</LABEL><MODULE>hdmi_player_top</MODULE><CREATEINDEX>user</CREATEINDEX></TOP_MODULE>
  <Property/><Device_Settings/><Configurations/>{runs}
</Project>
'''

def generate(staging, bitgen=False, route_effort='standard', place_seed=0):
    gui = ROOT/'td'
    gui.mkdir(exist_ok=True)
    (gui/f'{NAME}.al').write_text(project_xml(ROOT, gui, True), encoding='utf-8')
                                                                                  
    shutil.copy2(ROOT/'vendor/sdram/global_def.v', gui/'global_def.v')
    if staging is None:
        print(gui/f'{NAME}.al')
        return
    stage = Path(staging).resolve()
    if stage.exists():
        raise SystemExit(f'Refusing non-new staging directory: {stage}')
    stage.mkdir(parents=True)
    for folder in ('rtl','board','vendor','constraints'):
        shutil.copytree(ROOT/folder, stage/folder)
    (stage/'console/rtl').mkdir(parents=True)
    shutil.copy2(ROOT/'console/rtl/wav_stream_parser.v',
                 stage/'console/rtl/wav_stream_parser.v')
    shutil.copy2(ROOT/'console/rtl/wav_canonical_pcm_parser.v',
                 stage/'console/rtl/wav_canonical_pcm_parser.v')
    manifest = {str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest()
                for p in file_list(ROOT)+asset_list(ROOT)+list((ROOT/'constraints').glob('*'))+
                [ROOT/'vendor/sdram/global_def.v']}
    (stage/'source_sha256.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    for kind in ('syn_1','phy_1'):
        folder=stage/kind
        folder.mkdir()
        (folder/f'{NAME}.prj').write_text(project_xml(stage,folder,False),encoding='utf-8')
        shutil.copy2(ROOT/'vendor/sdram/global_def.v',folder/'global_def.v')
        config='''set ADCList {"../constraints/hx4s20c.adc"}
set SDCList {"../constraints/timing.sdc"}
set area_option -packarea
set device_name eagle_s20.db
set package_name EG4S20BG256
set prj_name Emergency_Info_Terminal
set top_model_name hdmi_player_top
'''
        config += ('set run_type syn\nset start_step read_design\nset end_step opt_gate\n' if kind=='syn_1'
                   else 'set run_type phy\nset parent ../syn_1\nset start_step opt_place\n'
                        f'set end_step {"bitgen" if bitgen else "opt_route"}\n'
                        'set_param place fix_hold high\n'
                        'set drHoldFix on\nset arr_filter on\nset arr_rwns -100000\n')
        if kind == 'syn_1':
            config += 'set synWildParams {gate eram_init on gate pack_effort high gate map_mode area_prior}\n'
        elif route_effort != 'standard' or place_seed:
            seed_options=f'flow enable_seed on place seed {place_seed} ' if place_seed else ''
            config += f'set phyWildParams {{{seed_options}route effort {route_effort}}}\n'
        (folder/'settings.cfg').write_text(config,encoding='utf-8')
    stages = 'synthesis, place, route, bitgen' if bitgen else 'synthesis, place, route'
    print(f'Offline build prepared: {stage}\nStages: {stages}; no programming.')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--staging',type=Path)
    parser.add_argument('--bitgen',action='store_true')
    parser.add_argument('--route-effort',choices=('standard','routability'),default='standard')
    parser.add_argument('--place-seed',type=int,default=0)
    args=parser.parse_args()
    generate(args.staging,args.bitgen,args.route_effort,args.place_seed)
