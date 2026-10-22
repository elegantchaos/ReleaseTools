// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 11/03/2020.
//  Copyright © 2020 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

extension CommandLine {
  /// Executable name used in user-facing command examples.
  public static var name: String {
    let url = URL(fileURLWithPath: arguments[0])
    return url.lastPathComponent
  }
}
