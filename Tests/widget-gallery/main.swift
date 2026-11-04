import Foundation

func check(_ condition: @autoclosure () -> Bool, _ description: String) {
    precondition(condition(), description)
}
check(BloomBoxWidgetGalleryPolicy.decode("clock,photo,notes") == ["clock", "photo", "notes"], "Old order")
check(BloomBoxWidgetGalleryPolicy.decode("clock,photo,clock,INVALID") == ["clock", "photo"], "Clean duplicates")
check(BloomBoxWidgetGalleryPolicy.decode(" notes , clock ") == ["notes", "clock"], "Trim whitespace")
check(BloomBoxWidgetGalleryPolicy.toggle("notes", in: "clock,photo") == "clock,photo,notes", "Add")
check(BloomBoxWidgetGalleryPolicy.toggle("clock", in: "clock,photo") == "photo", "Remove")
check(BloomBoxWidgetGalleryPolicy.toggle("INVALID", in: "clock,notes") == "clock,notes", "Unknown ignored")
let original = "notes,clock"
let added = BloomBoxWidgetGalleryPolicy.toggle("photo", in: original)
check(BloomBoxWidgetGalleryPolicy.toggle("photo", in: added) == original, "Toggle reversible")
print("PASS: BloomBox widget gallery restores historical order and reversible selections")
