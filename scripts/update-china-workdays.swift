#!/usr/bin/env swift

import Foundation

private struct HolidayDocument: Decodable {
    let year: Int
    let papers: [String]
    let days: [HolidayDay]
}

private struct HolidayDay: Decodable {
    let date: String
    let isOffDay: Bool
}

private struct Options {
    let years: [Int]
    let inputDirectory: URL?
    let output: URL
}

private enum UpdateError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(message): message
        }
    }
}

private let usage = """
用法：
  ./scripts/update-china-workdays.swift 2024...2027
  ./scripts/update-china-workdays.swift 2024 2025 2026 --input-directory /path/to/json

选项：
  --input-directory DIR  从本地 DIR/<年份>.json 读取，用于离线校验
  --output FILE         指定生成文件位置

更新下一年时请包含现有全部年份，例如从 2024–2026 扩展到 2027，应传入 2024...2027。
"""

private func absoluteURL(_ path: String, relativeTo base: URL) -> URL {
    URL(fileURLWithPath: path, relativeTo: base).standardizedFileURL
}

private func parseYears(_ tokens: [String]) throws -> [Int] {
    var values = Set<Int>()
    for token in tokens {
        if token.contains("...") {
            let bounds = token.components(separatedBy: "...")
            guard bounds.count == 2,
                  let first = Int(bounds[0]),
                  let last = Int(bounds[1]),
                  first <= last else {
                throw UpdateError.message("无效年份范围：\(token)")
            }
            values.formUnion(first...last)
        } else if let year = Int(token) {
            values.insert(year)
        } else {
            throw UpdateError.message("无效年份：\(token)")
        }
    }

    let years = values.sorted()
    guard let first = years.first, let last = years.last else {
        throw UpdateError.message("请至少指定一个年份。\n\n\(usage)")
    }
    guard years == Array(first...last) else {
        throw UpdateError.message("年份必须连续，避免生成不完整的支持范围。")
    }
    return years
}

private func parseOptions() throws -> Options {
    let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let scriptURL = absoluteURL(CommandLine.arguments[0], relativeTo: workingDirectory)
    let repositoryRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
    var inputDirectory: URL?
    var output = repositoryRoot
        .appendingPathComponent("Sources/FloatProgress/ChinaWorkdayData.generated.swift")
    var yearTokens: [String] = []
    var index = 1

    while index < CommandLine.arguments.count {
        let argument = CommandLine.arguments[index]
        switch argument {
        case "--input-directory", "--output":
            let valueIndex = index + 1
            guard valueIndex < CommandLine.arguments.count else {
                throw UpdateError.message("\(argument) 缺少路径。")
            }
            let value = absoluteURL(CommandLine.arguments[valueIndex], relativeTo: workingDirectory)
            if argument == "--input-directory" {
                inputDirectory = value
            } else {
                output = value
            }
            index += 2
        case "-h", "--help":
            print(usage)
            Foundation.exit(EXIT_SUCCESS)
        default:
            guard !argument.hasPrefix("--") else {
                throw UpdateError.message("未知选项：\(argument)")
            }
            yearTokens.append(argument)
            index += 1
        }
    }

    return Options(years: try parseYears(yearTokens), inputDirectory: inputDirectory, output: output)
}

private func loadDocument(year: Int, inputDirectory: URL?) throws -> HolidayDocument {
    let sourceURL: URL
    if let inputDirectory {
        sourceURL = inputDirectory.appendingPathComponent("\(year).json")
    } else {
        sourceURL = URL(string: "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/\(year).json")!
    }

    do {
        let data = try Data(contentsOf: sourceURL)
        let document = try JSONDecoder().decode(HolidayDocument.self, from: data)
        guard document.year == year else {
            throw UpdateError.message("\(year).json 内的年份是 \(document.year)，已停止生成。")
        }
        guard !document.days.isEmpty, !document.papers.isEmpty else {
            throw UpdateError.message("\(year).json 缺少日期或国务院公告来源。")
        }
        return document
    } catch let error as UpdateError {
        throw error
    } catch {
        throw UpdateError.message("读取 \(sourceURL.absoluteString) 失败：\(error.localizedDescription)")
    }
}

private func dateKey(_ value: String) throws -> (year: Int, key: Int) {
    let parts = value.split(separator: "-")
    guard parts.count == 3,
          let year = Int(parts[0]),
          let month = Int(parts[1]),
          let day = Int(parts[2]) else {
        throw UpdateError.message("无效日期：\(value)")
    }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let components = DateComponents(year: year, month: month, day: day)
    guard let date = calendar.date(from: components) else {
        throw UpdateError.message("无效日期：\(value)")
    }
    let checked = calendar.dateComponents([.year, .month, .day], from: date)
    guard checked.year == year, checked.month == month, checked.day == day else {
        throw UpdateError.message("无效日期：\(value)")
    }
    return (year, year * 10_000 + month * 100 + day)
}

private func swiftDate(_ key: Int) -> String {
    let year = key / 10_000
    let month = key / 100 % 100
    let day = key % 100
    return String(format: "%04d_%02d_%02d", year, month, day)
}

private func formattedSet(_ values: [Int]) -> String {
    guard !values.isEmpty else { return "[]" }
    let rows = stride(from: 0, to: values.count, by: 5).map { start -> String in
        let end = min(start + 5, values.count)
        let suffix = end < values.count ? "," : ""
        return "        " + values[start..<end].map(swiftDate).joined(separator: ", ") + suffix
    }
    return "[\n" + rows.joined(separator: "\n") + "\n    ]"
}

private func generatedSource(documents: [HolidayDocument], years: [Int]) throws -> String {
    let supportedYears = Set(years)
    var resolvedDays: [Int: Bool] = [:]
    for document in documents.sorted(by: { $0.year < $1.year }) {
        for day in document.days {
            let parsed = try dateKey(day.date)
            if supportedYears.contains(parsed.year) {
                // A later annual notice wins if it revises a date near a year boundary.
                resolvedDays[parsed.key] = day.isOffDay
            }
        }
    }

    let adjusted = resolvedDays.compactMap { $0.value ? nil : $0.key }.sorted()
    let holidays = resolvedDays.compactMap { $0.value ? $0.key : nil }.sorted()
    let firstYear = years.first!
    let lastYear = years.last!
    let notices = documents.sorted(by: { $0.year < $1.year }).flatMap { document in
        document.papers.map { "// \(document.year): \($0)" }
    }.joined(separator: "\n")

    return """
    // Generated by scripts/update-china-workdays.swift. Do not edit by hand.
    // Data source: https://github.com/NateScarlet/holiday-cn
    // Official notices:
    \(notices)

    enum ChinaWorkdayData {
        static let supportedYears = \(firstYear)...\(lastYear)
        static let coverageText = "已内置 \(firstYear)–\(lastYear) 年国务院安排"

        static let adjustedWorkdays: Set<Int> = \(formattedSet(adjusted))

        static let publicHolidays: Set<Int> = \(formattedSet(holidays))
    }
    """ + "\n"
}

do {
    let options = try parseOptions()
    let documents = try options.years.map { try loadDocument(year: $0, inputDirectory: options.inputDirectory) }
    let source = try generatedSource(documents: documents, years: options.years)
    try source.write(to: options.output, atomically: true, encoding: .utf8)
    print("已生成 \(options.output.path)")
    print("覆盖年份：\(options.years.first!)–\(options.years.last!)")
} catch {
    let message = "错误：\(error.localizedDescription)\n"
    FileHandle.standardError.write(Data(message.utf8))
    Foundation.exit(EXIT_FAILURE)
}
