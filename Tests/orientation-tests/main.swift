import Foundation

func check(_ size: CGSize, landscape: Bool, expected: CGSize) {
    let result = BloomBoxGuestSceneGeometry.size(size, landscape: landscape)
    precondition(result == expected,
                 "Orientation frame mismatch: \(size), landscape=\(landscape), actual=\(result), expected=\(expected)")
}

// iPhone-sized viewport (portrait -> landscape), and back again.
check(CGSize(width: 393, height: 852), landscape: true, expected: CGSize(width: 852, height: 393))
check(CGSize(width: 852, height: 393), landscape: true, expected: CGSize(width: 852, height: 393))
check(CGSize(width: 852, height: 393), landscape: false, expected: CGSize(width: 393, height: 852))
check(CGSize(width: 393, height: 852), landscape: false, expected: CGSize(width: 393, height: 852))
// Never alter valid zero or square dimensions.
check(.zero, landscape: true, expected: .zero)
check(CGSize(width: 500, height: 500), landscape: false, expected: CGSize(width: 500, height: 500))
print("PASS: guest orientation sizing preserves correct frames and corrects mismatched ones.")
