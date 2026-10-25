import Containerization
import Foundation

@main
struct ThreadedCgroupRepro {
    static func main() async {
        do {
            exit(try await reproduce() ? 1 : 0)
        } catch {
            print("UNEXPECTED FAILURE: \(error)")
            exit(2)
        }
    }

    static func reproduce() async throws -> Bool {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var manager = try await ContainerManager(
            kernel: Kernel(
                path: root.appendingPathComponent(".build/checkouts/containerization/.local/vmlinux-arm64"),
                platform: .linuxArm
            ),
            initfsReference: "ghcr.io/apple/containerization/vminit:0.53.0",
            // Keep guest versions separate: ContainerManager reuses cached initfs.ext4.
            root: root.appendingPathComponent(".repro/0.53.0")
        )
        let output = StandardOutput()
        var reproduced = false
        for kind in ["domain", "threaded"] {
            let id = "repro-\(kind)-\(UUID().uuidString.lowercased())"
            var vm: (any VirtualMachineInstance)?
            do {
                let container = try await manager.create(
                    id,
                    reference: "docker.io/library/alpine:3.22",
                    rootfsSizeInBytes: 128 * 1024 * 1024,
                    networking: false
                ) { config in
                    config.process.capabilities = .allCapabilities
                    config.process.stdout = output
                    config.process.stderr = output
                    config.process.arguments = [
                        "/bin/sh", "-ec",
                        """
                        mkdir /sys/fs/cgroup/nested
                        if [ '\(kind)' = threaded ]; then
                            echo threaded > /sys/fs/cgroup/nested/cgroup.type
                        fi
                        test "$(cat /sys/fs/cgroup/nested/cgroup.type)" = '\(kind)'
                        threads=$(cat /sys/fs/cgroup/nested/cgroup.threads)
                        test -z "$threads"
                        echo 'Created empty \(kind) cgroup; initial process exiting normally.'
                        """,
                    ]
                }
                try await container.create()
                let containerVM = try await container.withVirtualMachineInstance { $0 }
                vm = containerVM
                try await container.start()
                let status = try await container.wait(timeoutInSeconds: 30)
                guard status.exitCode == 0 else {
                    throw ReproError(message: "Guest setup failed with exit \(status.exitCode).")
                }
                do {
                    try await container.stop()
                    try output.write(Data("\(kind): stop() succeeded\n".utf8))
                } catch {
                    let message = String(describing: error)
                    guard kind == "threaded", message.contains("cgroup.kill"), message.contains("errno 95") else {
                        throw error
                    }
                    try output.write(Data("threaded: REPRODUCED: \(message)\n".utf8))
                    reproduced = true
                }
                guard case .stopped = containerVM.state else {
                    throw ReproError(message: "The VM is still running after stop().")
                }
            } catch {
                if let vm {
                    switch vm.state {
                    case .stopped: break
                    default: try await vm.stop()
                    }
                }
                let files = manager.imageStore.path.appendingPathComponent("containers/\(id)")
                if FileManager.default.fileExists(atPath: files.path) {
                    try manager.delete(id)
                }
                throw error
            }
            try manager.delete(id)
        }
        return reproduced
    }
}

fileprivate struct ReproError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

fileprivate struct StandardOutput: Writer {
    func write(_ data: Data) throws { try FileHandle.standardOutput.write(contentsOf: data) }
    // Guest output must not close the host's stdout.
    func close() throws {}
}
