import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property string cpuLoad: "—"
    property string memory: "—"
    property int memoryPercent: -1
    property string disk: "—"
    property int diskPercent: -1
    property string uptime: "—"
    property string gpu: "Detecting GPU"
    property string gpuDetail: ""
    property bool loading: false
    readonly property string recommendation: diskPercent >= 90
        ? "Disk usage is above 90%. Clear some space soon."
        : memoryPercent >= 85
            ? "Memory pressure is high. Closing an unused application may help."
            : cpuLoad !== "—" && Number(cpuLoad) >= 6
                ? "CPU load is elevated. Give heavy background work time to finish."
                : "System resources look comfortable. No action is needed."

    function refresh() {
        loading = true
        systemProcess.running = true
        gpuProcess.running = true
    }

    property Process systemProcess: Process {
        command: ["bash", "-lc", "awk '{print $1}' /proc/loadavg; free -m | awk '/^Mem:/{printf \"%d|%d|%d\\n\",$3,$2,($3/$2)*100}'; df -h / | awk 'NR==2{gsub(/%/,\"\",$5); printf \"%s|%s\\n\",$4,$5}'; uptime -p"]
        stdout: StdioCollector { id: systemOutput; waitForEnd: true }
        onExited: function(code) {
            var lines = String(systemOutput.text || "").trim().split("\n")
            if (code === 0 && lines.length >= 4) {
                root.cpuLoad = lines[0]
                var mem = lines[1].split("|")
                root.memory = mem[0] + " / " + mem[1] + " MB"
                root.memoryPercent = Number(mem[2])
                var storage = lines[2].split("|")
                root.disk = storage[0] + " free"
                root.diskPercent = Number(storage[1])
                root.uptime = lines[3].replace(/^up /, "")
            }
            root.loading = gpuProcess.running
        }
    }
    property Process gpuProcess: Process {
        command: ["bash", "-lc", "gpu=$(nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1); if [[ -n $gpu && $gpu != NVIDIA-SMI* ]]; then printf '%s\\n' \"$gpu\"; else lspci | awk -F': ' '/VGA|3D controller/{print $2; exit}'; fi"]
        stdout: StdioCollector { id: gpuOutput; waitForEnd: true }
        onExited: function(code) {
            var raw = String(gpuOutput.text || "").trim()
            var parts = raw.split(",")
            root.gpu = parts[0] || "GPU unavailable"
            root.gpuDetail = parts.length >= 3 ? parts[1].trim() + "% load · " + parts[2].trim() + "°C" : "Detected"
            root.loading = systemProcess.running
        }
    }
}
