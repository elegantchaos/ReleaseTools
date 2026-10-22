// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 30/03/2020.
//  Copyright © 2020 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

#if canImport(FoundationModels)
  import FoundationModels
#endif

/// Reads a repository’s revision range and renders Markdown changes, commits, and links.
/// Owns presentation flags and delegates Git queries to per-operation runners; an optional
/// Foundation Models summary falls back to the commit messages when unavailable.
struct ChangesCommand: AsyncParsableCommand {
  /// Repository whose history supplies the change log.
  @Option(name: .customLong("repo"), help: "Path to the git repository. Defaults to the current directory.")
  var repoPath: String = "."

  /// Optional starting revision, excluded from the change range.
  @Option(name: .customLong("start"), help: "Start reference for the change range (defaults to the previous tag).")
  var startRef: String?

  /// Ending revision included in the change range.
  @Option(name: .customLong("end"), help: "End reference for the change range.")
  var endRef: String = "HEAD"

  /// Whether merge commits contribute to the change log.
  @Flag(name: .customLong("include-merges"), help: "Include merge commits in the output.")
  var includeMerges = false

  /// Whether to append a commit list to the rendered changes.
  @Flag(
    name: .customLong("commits"),
    inversion: .prefixedNo,
    help: "Include a ## Commits section with hash + first-line summaries."
  )
  var includeCommits = true

  /// Whether to append the selected revision range.
  @Flag(
    name: .customLong("range"),
    inversion: .prefixedNo,
    help: "Include the range summary line in the output."
  )
  var includeRangeLine = true

  /// Whether to link commits and ranges to a GitHub origin.
  @Flag(
    name: .customLong("links"),
    inversion: .prefixedNo,
    help: "Include GitHub links in the output when a GitHub origin remote is available."
  )
  var includeLinks = true

  /// Whether to request an optional model-generated prose summary.
  @Flag(name: .customLong("summary"), help: "Add an AI-generated summary paragraph at the top when available.")
  var includeSummary = false

  /// Describes the `changes` command for ArgumentParser.
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "changes",
      abstract: "Show the change log since a previous version."
    )
  }

  /// Collects repository changes and prints the requested Markdown sections.
  func run() async throws {
    let repoURL = URL(fileURLWithPath: repoPath)
    guard FileManager.default.fileExists(atPath: repoURL.path) else {
      throw Error.repositoryNotFound(path: repoPath)
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

  /// Runs a Git query and captures its exit state and both output streams.
  private func runGit(_ arguments: [String], in repoURL: URL) async throws -> GitOutput {
    let git = GitRunner()
    git.cwd = repoURL
    let session = git.run(arguments)

    let state = await session.waitUntilExit()

    let stdout = await session.stdout.string

    let stderr = await session.stderr.string
    return GitOutput(state: state, stdout: stdout, stderr: stderr)
  }

  /// Returns Git output or throws a failure containing the command and stderr.
  private func runGitChecked(_ arguments: [String], in repoURL: URL) async throws -> String {
    let result = try await runGit(arguments, in: repoURL)
    guard case .succeeded = result.state else {
      throw Error.gitFailed(
        command: "git \(arguments.joined(separator: " "))",
        error: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
      )
    }
    return result.stdout
  }

  /// Resolves a revision expression to its full commit identifier.
  private func resolvedCommit(for ref: String, in repoURL: URL) async throws -> String {
    let output = try await runGitChecked(["rev-parse", "\(ref)^{commit}"], in: repoURL)
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Checks reachability, treating Git’s unrelated-revision result separately from failures.
  private func isAncestor(_ ancestorRef: String, of descendantRef: String, in repoURL: URL) async throws -> Bool {
    let result = try await runGit(["merge-base", "--is-ancestor", ancestorRef, descendantRef], in: repoURL)
    switch result.state {
      case .succeeded:
        return true

      case .failed(let code):
        if code == 1 {
          return false
        }
        throw Error.gitFailed(
          command: "git merge-base --is-ancestor \(ancestorRef) \(descendantRef)",
          error: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        )

      case .startup(let error):
        throw Error.gitFailed(
          command: "git merge-base --is-ancestor \(ancestorRef) \(descendantRef)",
          error: error
        )

      case .uncaughtSignal, .unknown:
        throw Error.gitFailed(
          command: "git merge-base --is-ancestor \(ancestorRef) \(descendantRef)",
          error: "\(result.state)"
        )
    }
  }

  /// Finds the newest version-sorted reachable tag before the ending commit.
  private func detectPreviousTag(endRef: String, in repoURL: URL) async throws -> String? {
    let endCommit = try await resolvedCommit(for: endRef, in: repoURL)
    let tagsOutput = try await runGitChecked(["tag", "--sort=-v:refname"], in: repoURL)
    let tags =
      tagsOutput
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

  /// Reads commits in chronological order, retaining their complete nonempty message lines.
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

  /// Converts supported GitHub origin URLs into a browser URL for change links.
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

  /// Renders change bullets and the requested commit, link, and range sections.
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
    if includeSummary, let summary {
      lines.append(summary)
      lines.append("")
    } else {
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

  /// Returns an accepted model summary when requested and available.
  private func summaryParagraph(commits: [Commit]) async -> String? {
    guard includeSummary, !commits.isEmpty else {
      return nil
    }

    #if canImport(FoundationModels)
      guard let summary = await generateSummaryWithFoundationModels(commits: commits) else {
        return nil
      }
      return validatedSummary(summary)
    #else
      return nil
    #endif
  }

  /// Rejects empty, list-like, and formulaic model responses before publication.
  private func validatedSummary(_ summary: String) -> String? {
    let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if trimmed.contains("- ") || trimmed.contains("•") { return nil }
    let lowercase = trimmed.lowercased()
    let bannedPrefixes = [
      "the release updates included",
      "the release changes included",
      "the release included",
      "this release",
      "release updates included",
      "release changes included",
      "the updates included",
      "the changes included",
    ]
    if bannedPrefixes.contains(where: { lowercase.hasPrefix($0) }) {
      return nil
    }

    // Reject list-like sentence structure (many comma clauses ending in ", and ...").
    if !trimmed.contains("\n"), trimmed.filter({ $0 == "," }).count >= 3, lowercase.contains(", and ") {
      return nil
    }
    return trimmed
  }

  #if canImport(FoundationModels)
    /// Asks the available system model for a short prose summary of the commits.
    @available(macOS 26.0, *)
    private func generateSummaryWithFoundationModelsAvailable(commits: [Commit]) async -> String? {
      let model = SystemLanguageModel.default
      guard case .available = model.availability else {
        return nil
      }

      let bulletList =
        commits
        .map { "- \($0.messageLines.first ?? $0.subject)" }
        .joined(separator: "\n")
      let instructions = """
        Summarize release changes in approachable, informational prose.
        Use past tense. Produce a short paragraph of 1-2 complete sentences with proper punctuation.
        Start directly with the changes and never use framing like "This release", "The release updates included", or similar preambles.
        Do not produce list formatting, semicolon-separated clause chains, or marketing language. Do not mention commit hashes.
        """
      let prompt = """
        Summarize these release changes:
        \(bulletList)
        """

      do {
        let session = LanguageModelSession(instructions: instructions)
        let options = GenerationOptions(temperature: 0.2)
        let response = try await session.respond(to: prompt, options: options)
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
      } catch {
        return nil
      }
    }

    /// Requests a summary when Foundation Models is supported by the current OS.
    private func generateSummaryWithFoundationModels(commits: [Commit]) async -> String? {
      guard #available(macOS 26.0, *) else {
        return nil
      }
      return await generateSummaryWithFoundationModelsAvailable(commits: commits)
    }
  #endif
}

extension ChangesCommand {
  /// Errors emitted while collecting a repository's changes.
  enum Error: Swift.Error, LocalizedError {
    /// The supplied repository path does not exist.
    case repositoryNotFound(path: String)

    /// A git query failed while generating the change log.
    case gitFailed(command: String, error: String)

    /// A user-facing description of the failure.
    var errorDescription: String? {
      switch self {
        case .repositoryNotFound(let path):
          return "Repository path doesn't exist: \(path)"
        case .gitFailed(let command, let error):
          return "Git command failed: \(command)\n\(error)"
      }
    }
  }
}

extension ChangesCommand {
  /// Captured output and completion state from one Git query.
  private struct GitOutput {
    /// Completion status of the Git process.
    let state: RunState

    /// Captured standard output.
    let stdout: String

    /// Captured error output.
    let stderr: String
  }

  /// Commit identity and message lines used to render a change log.
  private struct Commit {
    /// Abbreviated commit identifier used for displayed links.
    let shortHash: String

    /// First message line used in the commit list.
    let subject: String

    /// Nonempty message lines rendered as change bullets.
    let messageLines: [String]
  }
}
