//
//  Shell.swift
//  V2rayU
//
//  Created by yanue on 2024/12/25.
//  Copyright © 2024 yanue. All rights reserved.

import Foundation

//  run custom shell
// demo:
// shell("/bin/bash",["-c","ls"])
// shell("/bin/bash",["-c","cd ~ && ls -la"])
func shell(launchPath: String, arguments: [String]) -> String? {
    do {
        let output = try runCommand(at: launchPath, with: arguments)
        return output
    } catch let error {
        logger.info("shell error: \(error)")
        return ""
    }
}

enum CommandExecutionError: Error {
    case fileNotFound(String)
    case insufficientPermissions(String)
    case executionFailed(String, Int32) // stderr + exit code
    case unknown(Error)
}

func runCommand(at path: String, with arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // 检查退出码
        if process.terminationStatus != 0 {
            throw CommandExecutionError.executionFailed(output, process.terminationStatus)
        }

        return output
    } catch {
        if (error as NSError).domain == NSCocoaErrorDomain {
            switch (error as NSError).code {
            case NSFileNoSuchFileError:
                throw CommandExecutionError.fileNotFound(path)
            case NSFileReadNoPermissionError:
                throw CommandExecutionError.insufficientPermissions(path)
            default:
                throw CommandExecutionError.unknown(error)
            }
        } else {
            throw CommandExecutionError.unknown(error)
        }
    }
}

func killProcess(processIdentifier: pid_t) {
    do {
        let result = kill(processIdentifier, SIGKILL)
        if result == -1 {
            logger.info("killProcess: Failed to kill process with identifier \(processIdentifier)")
        } else {
            logger.info("killProcess: Successfully killed process with identifier \(processIdentifier)")
        }
    }
}

func killAllPing() {
    let pskillCmd = "ps aux | grep v2ray | grep '.V2rayU/.config.' | awk '{print $2}' | xargs kill"
    let msg = shell(launchPath: "/bin/bash", arguments: ["-c", pskillCmd])
    logger.info("killAllPing: \(String(describing: msg))")
    let rmPingJsonCmd = "rm -f ~/.V2rayU/.config.*.json"
    let msg1 = shell(launchPath: "/bin/bash", arguments: ["-c", rmPingJsonCmd])
    logger.info("rmPingJson: \(String(describing: msg1))")
}

func killSelfV2ray() {
    let pskillCmd = "ps aux | grep v2ray | grep '.V2rayU/config.json' | awk '{print $2}' | xargs kill"
    let msg = shell(launchPath: "/bin/bash", arguments: ["-c", pskillCmd])
    logger.info("killSelfV2ray: \(String(describing: msg))")
}
