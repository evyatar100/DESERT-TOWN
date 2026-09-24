import os
import sys
import zlib
import glob

try:
    import rubymarshal
    from rubymarshal.reader import load
    from rubymarshal.writer import write
    from rubymarshal.classes import Symbol
except ImportError:
    print("Installing rubymarshal...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "rubymarshal"])
    import rubymarshal
    from rubymarshal.reader import load
    from rubymarshal.writer import write
    from rubymarshal.classes import Symbol

def compile_all_plugins():
    plugin_scripts_path = os.path.join("Data", "PluginScripts.rxdata")
    plugins_dir = "Plugins"

    plugins = []
    plugin_folders = [f for f in sorted(os.listdir(plugins_dir)) if os.path.isdir(os.path.join(plugins_dir, f))]

    for folder in plugin_folders:
        plugin_path = os.path.join(plugins_dir, folder)
        meta_path = os.path.join(plugin_path, "meta.txt")
        if not os.path.exists(meta_path):
            continue

        meta = {
            Symbol("name"): folder,
            Symbol("version"): "1.0.0",
            Symbol("essentials"): ["21.1"],
            Symbol("incompatibilities"): [],
            Symbol("link"): "https://github.com",
            Symbol("credits"): ["Developer"]
        }

        with open(meta_path, "r", encoding="utf-8-sig", errors="ignore") as mf:
            for line in mf:
                if "=" in line:
                    k, v = line.strip().split("=", 1)
                    k, v = k.strip().lower(), v.strip()
                    if k == "name":
                        meta[Symbol("name")] = v
                    elif k == "version":
                        meta[Symbol("version")] = v
                    elif k == "essentials":
                        meta[Symbol("essentials")] = [x.strip() for x in v.split(",") if x.strip()]
                    elif k == "credits":
                        meta[Symbol("credits")] = [x.strip() for x in v.split(",") if x.strip()]
                    elif k in ["link", "website"]:
                        meta[Symbol("link")] = v
                    elif k in ["conflicts", "incompatibilities"]:
                        meta[Symbol("incompatibilities")].extend([x.strip() for x in v.split(",") if x.strip()])

        script_files = sorted(glob.glob(os.path.join(plugin_path, "*.rb")))
        compiled_scripts = []
        for sfile in script_files:
            basename = os.path.basename(sfile)
            with open(sfile, "r", encoding="utf-8", errors="ignore") as sf:
                code = sf.read()
            compressed = zlib.compress(code.encode("utf-8"))
            compiled_scripts.append([basename, compressed])

        plugins.append([meta[Symbol("name")], meta, compiled_scripts])
        print(f"Compiled plugin '{meta[Symbol('name')]}' with {len(compiled_scripts)} scripts.")

    with open(plugin_scripts_path, "wb") as f:
        write(f, plugins)

    print(f"Successfully compiled all plugins into {plugin_scripts_path}")

if __name__ == "__main__":
    compile_all_plugins()
