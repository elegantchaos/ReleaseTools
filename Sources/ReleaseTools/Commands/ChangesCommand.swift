// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 30/03/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner
#if canImport(FoundationModels)
import FoundationModels
#endif

enum ChangesError: Error {
  case repositoryNotFound(path: String)
  case gitFailed(command: String, error: String)
}

extension ChangesError: LocalizedError {
  public var errorDescription: String? {
    switch self {
      case .repositoryNotFound(let path):
        return "Repository path doesn't exist: \(path)"

      case .gitFailed(let command, let error):
        return "Git command failed: \(command)\n\(error)"
    }
  }
}

struct ChangesCommand: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "changes",
      abstract: "Show the change log since a previous version."
    )
  }

  @Option(name: .customLong("repo"), help: "Path to the git repository. Defaults to the current directory.")
  var repoPath: String = "."
  @Option(name: .customLong("start"), help: "Start reference for the change range (defaults to the previous tag).")
  var startRef: String?
  @Option(name: .customLong("end"), help: "End reference for the change range.")
  var endRef: String = "HEAD"
  @Flag(name: .customLong("include-merges"), help: "Include merge commits in the output.")
  var includeMerges = false
  @Flag(
    name: .customLong("commits"),
    inversion: .prefixedNo,
    help: "Include a ## Commits section with hash + first-line summaries."
  )
  var includeCommits = true
  @Flag(
    name: .customLong("range"),
    inversion: .prefixedNo,
    help: "Include the range summary line in the output."
  )
  var includeRangeLine = true
  @Flag(
    name: .customLong("links"),
    inversion: .prefixedNo,
    help: "Include GitHub links in the output when a GitHub origin remote is available."
  )
  var includeLinks = true
  @Flag(name: .customLong("summary"), help: "Add an AI-generated summary paragraph at the top when available.")
  var includeSummary = false

  private struct GitOutput {
    let state: RunState
    let stdout: String
    let stderr: String
  }

  private struct Commit {
    let shortHash: String
    let subject: String
    let messageLines: [String]
  }

  private func runGit(_ arguments: [String], in repoURL: URL) async throws -> GitOutput {
    let git = GitRunner()
    git.cwd = repoURL
    let session = git.run(arguments)
    let state = await session.waitUntilExit()
    let stdout = await session.stdout.string
    let stderr = await session.stderr.string
    return GitOutput(state: state, stdout: stdout, stderr: stderr)
  }

  private func runGitChecked(_ arguments: [String], in repoURL: URL) async throws -> String {
    let result = try await runGit(arguments, in: repoURL)
    guard case .succeeded = result.state else {
      throw ChangesError.gitFailed(
        command: "git \(arguments.joined(separator: " "))",
        error: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
      )
    }
    return result.stdout
  }

  private func resolvedCommit(for ref: String, in repoURL: URL) async throws -> String {
    let output = try await runGitChecked(["rev-parse", "\(ref)^{commit}"], in: repoURL)
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func isAncestor(_ ancestorRef: String, of descendantRef: String, in repoURL: URL) async throws -> Bool {
    let result = try await runGit(["merge-base", "--is-ancestor", ancestorRef, descendantRef], in: repoURL)
    switch result.state {
      case .succeeded:
        return true

      case .failed(let code):
        if code == 1 {
          return false
        }
        throw ChangesError.gitFailed(
          command: "git merge-base --is-ancestor \(ancestorRef) \(descendantRef)",
          error: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        )

      case .startup(let error):
        throw ChangesError.gitFailed(
          command: "git merge-base --is-ancestor \(ancestorRef) \(descendantRef)",
          error: error
        )

      case .uncaughtSignal, .unknown:
        throw ChangesError.gitFailed(
          command: "git merge-base --is-ancestor \(ancestorRef) \(descendantRef)",
          error: "\(result.state)"
        )
    }
  }

  private func detectPreviousTag(endRef: String, in repoURL: URL) async throws -> String? {
    let endCommit = try await resolvedCommit(for: endRef, in: repoURL)
    let tagsOutput = try await runGitChecked(["tag", "--sort=-v:refname"], in: repoURL)
    let tags = tagsOutput
      .split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    for tag in tags {
      guard try await isAncestor(tag, of: endRef, in: repoURL) else {
        continue
      }

      let tagCommit = try await resolvedCommit(for: tag, in: repoURL)
      if tagCommit == endCommit {
        continue
      }

      return tag
    }

    return nil
  }

  private func collectCommits(range: String, in repoURL: URL) async throws -> [Commit] {
    var arguments = ["log", "--reverse", "--pretty=format:%h%x1f%B%x1e"]
    if !includeMerges {
      arguments.append("--no-merges")
    }
    arguments.append(range)

    let output = try await runGitChecked(arguments, in: repoURL)
    let records = output.split(separator: "\u{1e}")
    return records.compactMap { record in
      let parts = record.split(separator: "\u{1f}", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { return nil }

      let hash = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
      let lines = parts[1]
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { String($0).trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
      let subject = lines.first ?? ""
      return Commit(shortHash: hash, subject: subject, messageLines: lines)
    }
  }

  private func githubRemoteURL(in repoURL: URL) async throws -> URL? {
    let result = try await runGit(["config", "--get", "remote.origin.url"], in: repoURL)
    guard case .succeeded = result.state else {
      return nil
    }

    let remote = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !remote.isEmpty else {
      return nil
    }

    if remote.hasPrefix("git@github.com:") {
      let suffix = remote.dropFirst("git@github.com:".count)
      let path = suffix.hasSuffix(".git") ? String(suffix.dropLast(4)) : String(suffix)
      return URL(string: "https://github.com/\(path)")
    }

    if remote.hasPrefix("ssh://git@github.com/") {
      let suffix = remote.dropFirst("ssh://git@github.com/".count)
      let path = suffix.hasSuffix(".git") ? String(suffix.dropLast(4)) : String(suffix)
      return URL(string: "https://github.com/\(path)")
    }

    guard let url = URL(string: remote), url.host == "github.com" else {
      return nil
    }

    let path = url.path.hasSuffix(".git") ? String(url.path.dropLast(4)) : url.path
    return URL(string: "https://github.com\(path)")
  }

  private func formatChanges(
    previousTag: String?,
    range: String,
    startRef: String?,
    endRef: String,
    commits: [Commit],
    githubURL: URL?,
    summary: String?
  ) -> String {
    var lines: [String] = []
    if let previousTag {
      lines.append("## Changes since \(previousTag)")
    } else {
      lines.append("## Changes")
    }
    lines.append("")
    if let summary {
      lines.append(summary)
      lines.append("")
    }

    if commits.isEmpty {
      lines.append("- No non-merge commits found in this range.")
    } else {
      for commit in commits {
        if let firstLine = commit.messageLines.first {
          lines.append("- \(firstLine)")
          for additionalLine in commit.messageLines.dropFirst() {
            lines.append("  - \(additionalLine)")
          }
        }
      }
    }

    if includeCommits {
      lines.append("")
      lines.append("## Commits")
      lines.append("")
      if commits.isEmpty {
        lines.append("- (none)")
      } else {
        for commit in commits {
          if includeLinks, let githubURL {
            lines.append("- [`\(commit.shortHash)`](\(githubURL.absoluteString)/commit/\(commit.shortHash)) \(commit.subject)")
          } else {
            lines.append("- \(commit.shortHash) \(commit.subject)")
          }
        }
      }
    }

    if includeRangeLine {
      lines.append("")
      let formattedRange: String
      if includeLinks, let githubURL, let startRef {
        formattedRange = "[`\(range)`](\(githubURL.absoluteString)/compare/\(startRef)...\(endRef))"
      } else {
        formattedRange = "`\(range)`"
      }

      lines.append("_Range: \(formattedRange) • End: `\(endRef)`_")
    }

    return lines.joined(separator: "\n")
  }

  private func summaryParagraph(commits: [Commit]) async -> String? {
    guard includeSummary, !commits.isEmpty else {
      return nil
    }

    #if canImport(FoundationModels)
      guard let summary = await generateSummaryWithFoundationModels(commits: commits) else {
        return nil
      }
      return validatedSummary(summary, commits: commits)
    #else
      return nil
    #endif
  }

  private func validatedSummary(_ summary: String, commits: [Commit]) -> String? {
    let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if trimmed.contains("- ") || trimmed.contains("•") { return nil }

    let commitText = commits
      .compactMap(\.messageLines.first)
      .joined(separator: " ")

    let summaryWords = Set(normalizedWords(trimmed))
    let commitWords = Set(normalizedWords(commitText))
    guard !summaryWords.isEmpty, !commitWords.isEmpty else {
      return nil
    }

    let overlap = summaryWords.intersection(commitWords).count
    let similarity = Double(overlap) / Double(summaryWords.count)
    if similarity >= 0.9 {
      return nil
    }

    return trimmed
  }

  private func normalizedWords(_ text: String) -> [String] {
    text.lowercased()
      .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
      .split(separator: " ")
      .map(String.init)
  }

  #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func generateSummaryWithFoundationModelsAvailable(commits: [Commit]) async -> String? {
      let model = SystemLanguageModel.default
      guard case .available = model.availability else {
        return nil
      }

      let bulletList = commits
        .map { "- \($0.messageLines.first ?? $0.subject)" }
        .joined(separator: "\n")
      let prompt = """
        Write exactly one concise sentence summarizing these release changes.
        Use past tense.
        Start directly with the changes (for example, "Enhanced...", "Updated...", "Fixed...").
        Do not use introductory framing like "The release changes focus on..." or "This release...".
        Do not include motivations, goals, or marketing language (for example, avoid phrases like "to improve", "to streamline", "to provide better").
        Keep it strictly informational and concrete.
        Do not restate the commit list line-by-line, and do not closely paraphrase every item.
        If a useful higher-level summary is not possible without repeating the list, return an empty string.
        Do not use markdown list formatting.
        Do not mention commit hashes.
        Changes:
        \(bulletList)
        """

      do {
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
      } catch {
        return nil
      }
    }

    private func generateSummaryWithFoundationModels(commits: [Commit]) async -> String? {
      guard #available(macOS 26.0, *) else {
        return nil
      }
      return await generateSummaryWithFoundationModelsAvailable(commits: commits)
    }
  #endif

  func run() async throws {
    let repoURL = URL(fileURLWithPath: repoPath)
    guard FileManager.default.fileExists(atPath: repoURL.path) else {
      throw ChangesError.repositoryNotFound(path: repoPath)
    }

    let resolvedStartRef: String?
    if let suppliedStartRef = startRef {
      resolvedStartRef = suppliedStartRef
    } else {
      resolvedStartRef = try await detectPreviousTag(endRef: endRef, in: repoURL)
    }
    let range = resolvedStartRef.map { "\($0)..\(endRef)" } ?? endRef
    let commits = try await collectCommits(range: range, in: repoURL)
    let githubURL = includeLinks ? try await githubRemoteURL(in: repoURL) : nil
    let summary = await summaryParagraph(commits: commits)

    print(
      formatChanges(
        previousTag: resolvedStartRef,
        range: range,
        startRef: resolvedStartRef,
        endRef: endRef,
        commits: commits,
        githubURL: githubURL,
        summary: summary
      )
    )
  }
}
