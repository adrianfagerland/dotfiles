#!/bin/sh

/usr/bin/swift -e 'import CoreGraphics
import Foundation

let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []

for win in list {
  let layer = win[kCGWindowLayer as String] as? Int ?? -1
  if layer != 0 { continue }

  let id = win[kCGWindowNumber as String] as? Int ?? -1
  if id < 0 { continue }

  let bounds = win[kCGWindowBounds as String] as? [String: Any] ?? [:]
  let x = bounds["X"] as? Double ?? -1
  print("\(id)|\(Int(x))")
}'
