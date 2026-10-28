// Composite every on-screen SketchyBar window below the bar into one PNG.
// SketchyBar windows live in a private sticky space that screencapture skips,
// so each window is captured individually through SkyLight.
//
// Build: swiftc -O -F/System/Library/PrivateFrameworks -framework SkyLight \
//          bench/capture_popup.swift -o bench/capture_popup
// Usage: bench/capture_popup <out.png> [min_y] [min_x] [max_x]
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@_silgen_name("SLSMainConnectionID")
func SLSMainConnectionID() -> Int32

@_silgen_name("SLSCaptureWindowsContentsToRectWithOptions")
func SLSCaptureWindowsContentsToRectWithOptions(
  _ cid: Int32, _ wid: UnsafeMutablePointer<UInt64>, _ meh: Bool, _ bounds: CGRect,
  _ flags: UInt32, _ image: UnsafeMutablePointer<Unmanaged<CGImage>?>)

let args = CommandLine.arguments
guard args.count >= 2 else {
  FileHandle.standardError.write("usage: capture_popup <out.png> [min_y]\n".data(using: .utf8)!)
  exit(2)
}
let minY = args.count >= 3 ? Double(args[2]) ?? 1 : 1
let minX = args.count >= 4 ? Double(args[3]) ?? -9000 : -9000
let maxX = args.count >= 5 ? Double(args[4]) ?? 99999 : 99999

let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
var windows: [(id: UInt64, frame: CGRect)] = []
for w in info where (w[kCGWindowOwnerName as String] as? String) == "sketchybar" {
  let b = w[kCGWindowBounds as String] as! [String: Double]
  let frame = CGRect(x: b["X"]!, y: b["Y"]!, width: b["Width"]!, height: b["Height"]!)
  if frame.minY < minY || frame.width <= 1 || frame.minX < minX || frame.maxX > maxX { continue }
  windows.append((UInt64(w[kCGWindowNumber as String] as! Int), frame))
}
guard !windows.isEmpty else {
  FileHandle.standardError.write("no popup windows on screen\n".data(using: .utf8)!)
  exit(1)
}

let union = windows.dropFirst().reduce(windows[0].frame) { $0.union($1.frame) }
let scale = 2.0
let width = Int(union.width * scale), height = Int(union.height * scale)
let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setFillColor(CGColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

let cid = SLSMainConnectionID()
// CGWindowList is front-to-back; paint back-to-front.
for window in windows.reversed() {
  var wid = window.id
  var image: Unmanaged<CGImage>?
  SLSCaptureWindowsContentsToRectWithOptions(cid, &wid, true, .null, 1 << 8, &image)
  guard let cgImage = image?.takeRetainedValue() else { continue }
  let rect = CGRect(x: (window.frame.minX - union.minX) * scale,
                    y: (union.maxY - window.frame.maxY) * scale,
                    width: window.frame.width * scale, height: window.frame.height * scale)
  ctx.draw(cgImage, in: rect)
}

let url = URL(fileURLWithPath: args[1]) as CFURL
let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
print("captured \(windows.count) windows, union \(union)")
