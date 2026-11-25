"""Tarik sumber skrip dari Roblox Studio ke folder proyek lewat berkas log Studio.

Dipakai saat plugin Rojo tidak tersambung. Di Studio (command bar / MCP) jalankan
cuplikan Luau di bawah dengan daftar jalur skrip; ia mencetak isi skrip dalam
bentuk heksadesimal ke Output, yang ikut tertulis di log Studio. Lalu jalankan:

    python tools/studio_pull.py <ID>

Cuplikan Luau:

    local ID = "P1"
    for _, path in { "ReplicatedStorage.Shared.Config" } do
        local inst = game
        for seg in path:gmatch("[^%.]+") do inst = inst[seg] end
        local s = inst.Source
        print("@@BEGIN " .. ID .. " " .. path .. " " .. #s)
        for i = 1, #s, 100 do
            print("@@D " .. ID .. " " .. (s:sub(i, i + 99):gsub(".", function(c)
                return string.format("%02x", c:byte())
            end)))
        end
        print("@@END " .. ID .. " " .. path)
    end
"""

import glob
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PREFIXES = [
    ("ReplicatedStorage.Shared.", "src/shared/"),
    ("ServerScriptService.Server.", "src/server/"),
    ("StarterPlayer.StarterPlayerScripts.Client.", "src/client/"),
    ("ServerStorage.MapBuilders.", "map/"),
]
EXACT = {
    "ServerScriptService.Server": "src/server/init.server.luau",
    "StarterPlayer.StarterPlayerScripts.Client": "src/client/init.client.luau",
}


def disk_path(studio_path: str) -> str:
    if studio_path in EXACT:
        return EXACT[studio_path]
    for prefix, folder in PREFIXES:
        if studio_path.startswith(prefix):
            return folder + studio_path[len(prefix):].replace(".", "/") + ".luau"
    raise SystemExit("Jalur tidak dikenal: " + studio_path)


def main() -> None:
    pull_id = sys.argv[1]
    logs = sorted(
        glob.glob(os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "logs", "*Studio*.log")),
        key=os.path.getmtime,
    )
    found: dict[str, tuple[int, bytearray]] = {}
    for log in logs[-4:]:
        current = None
        with open(log, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                at = line.find("@@")
                if at < 0:
                    continue
                parts = line[at:].split()
                if len(parts) < 3 or parts[1] != pull_id:
                    continue
                if parts[0] == "@@BEGIN":
                    current = parts[2]
                    found[current] = (int(parts[3]), bytearray())
                elif parts[0] == "@@D" and current:
                    found[current][1].extend(bytes.fromhex(parts[2]))
                elif parts[0] == "@@END":
                    current = None
    if not found:
        raise SystemExit("Tidak ada data untuk ID " + pull_id)
    for studio_path, (size, data) in found.items():
        target = os.path.join(ROOT, disk_path(studio_path))
        if len(data) != size:
            print(f"GAGAL {studio_path}: {len(data)} dari {size} byte")
            continue
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "wb") as handle:
            handle.write(bytes(data))
        print(f"ok {studio_path} -> {disk_path(studio_path)} ({size} byte)")


if __name__ == "__main__":
    main()
