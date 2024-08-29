import Runner

// TODO: move into Runner
extension Runner.RunningProcess {
  /// Check the state of the process and throw an error if it failed.
  func throwIfFailed(_ e: @autoclosure () async -> Error) async throws {
    for await state in self.state {
      if state != .succeeded {
        throw await e()
      }
    }
  }
}
