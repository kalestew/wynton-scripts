import sys
import re

def parse_fixed_format(lines):
    data = {}
    current_key = None
    current_value = ""

    for line in lines:
        if not line.strip():
            continue

        if re.match(r"^\S+\s{2,}", line):
            if current_key:
                data[current_key] = current_value.strip().rstrip(",\\")
            key, val = re.split(r"\s{2,}", line.strip(), maxsplit=1)
            current_key = key.strip()
            current_value = val.strip().rstrip(",\\")
        else:
            current_value += line.strip().rstrip(",\\")

    if current_key:
        data[current_key] = current_value.strip().rstrip(",\\")
    return data


def parse_embedded_kv(string):
    kv = {}
    for part in re.split(r',(?![^\[]*\])', string):
        if '=' in part:
            k, v = part.strip().split('=', 1)
            kv[k.strip()] = v.strip()
    return kv


def parse_with_units(val, target_unit="MB"):
    """Converts string with optional unit suffix (M, G, k) to float in target unit."""
    if not val:
        return 0.0
    val = val.strip().upper()
    multiplier = 1.0

    if val.endswith("K"):
        multiplier = 1.0 / 1024
        val = val[:-1]
    elif val.endswith("M"):
        multiplier = 1.0
        val = val[:-1]
    elif val.endswith("G"):
        multiplier = 1024
        val = val[:-1]

    try:
        return float(val) * multiplier
    except ValueError:
        return 0.0


def human_readable_report(data):
    report = []

    hostname = data.get("hostname", "unknown")
    report.append(f"🖥️ Node: {hostname}\n")

    load_vals = parse_embedded_kv(data.get("load_values", ""))
    gpu_names = load_vals.get("gpu.names", "")
    gpu_list = gpu_names.split(';') if gpu_names else []

    cpu_cores = load_vals.get("num_proc", "N/A")
    cpu_usage = float(load_vals.get("cpu", 0.0))
    mem_total = parse_with_units(load_vals.get("mem_total", "0"))
    mem_used = parse_with_units(load_vals.get("mem_used", "0"))
    mem_free = parse_with_units(load_vals.get("mem_free", "0"))
    swap_total = parse_with_units(load_vals.get("swap_total", "0"))
    swap_used = parse_with_units(load_vals.get("swap_used", "0"))
    swap_free = parse_with_units(load_vals.get("swap_free", "0"))
    scratch = parse_with_units(load_vals.get("scratch", "0"), target_unit="GB")

    report.append("### System Overview")
    report.append(f"- CPU Threads: {cpu_cores}")
    report.append(f"- CPU Load: {cpu_usage:.1f}%")
    report.append(f"- Memory: {mem_total:.1f} MB total / {mem_used:.1f} MB used / {mem_free:.1f} MB free")
    report.append(f"- Swap: {swap_total:.1f} MB total / {swap_used:.1f} MB used / {swap_free:.1f} MB free")
    report.append(f"- SSD Scratch: {scratch:.1f} GB\n")

    report.append("### Load Averages")
    report.append(f"- 1-min: {load_vals.get('load_short', 'N/A')}")
    report.append(f"- 5-min: {load_vals.get('load_avg', 'N/A')}")
    report.append(f"- 15-min: {load_vals.get('load_long', 'N/A')}\n")

    report.append("### 🎮 GPUs")
    for idx, name in enumerate(gpu_list):
        name = name.strip()
        if not name:
            continue
        mem_free = int(load_vals.get(f"gpu.cuda.{idx}.mem_free", 0))
        mem_free_gb = mem_free / (1024 ** 3)
        util = load_vals.get(f"gpu.cuda.{idx}.util", "N/A")
        procs = load_vals.get(f"gpu.cuda.{idx}.procs", "N/A")
        clock = load_vals.get(f"gpu.cuda.{idx}.clock", "N/A")

        report.append(f"#### GPU {idx} — {name}")
        report.append(f"- Utilization: {util}%")
        report.append(f"- Processes Running: {procs}")
        report.append(f"- Memory Free: {mem_free_gb:.2f} GB")
        report.append(f"- Clock Speed: {clock} MHz\n")

    return "\n".join(report)


if __name__ == "__main__":
    input_lines = sys.stdin.read().splitlines()
    parsed = parse_fixed_format(input_lines)
    print(human_readable_report(parsed))
