import AppKit
import CoreGraphics
import Foundation

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
func rgb(_ r: CGFloat,_ g: CGFloat,_ b: CGFloat,_ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: cs, components:[r,g,b,a])! }
func point(_ x: CGFloat,_ y: CGFloat, shiftX: CGFloat = 0, shiftY: CGFloat = 0) -> CGPoint { CGPoint(x:x*CGFloat(size)+shiftX,y:y*CGFloat(size)+shiftY) }
func apple(_ dx: CGFloat = 0,_ dy: CGFloat = 0) -> CGPath {
    let p=CGMutablePath()
    func pt(_ x:CGFloat,_ y:CGFloat)->CGPoint {point(x,y,shiftX:dx,shiftY:dy)}
    p.move(to:pt(0.50,0.67))
    p.addCurve(to:pt(0.72,0.69),control1:pt(0.58,0.74),control2:pt(0.66,0.72))
    p.addCurve(to:pt(0.82,0.52),control1:pt(0.84,0.71),control2:pt(0.86,0.62))
    p.addCurve(to:pt(0.72,0.30),control1:pt(0.80,0.40),control2:pt(0.76,0.33))
    p.addCurve(to:pt(0.60,0.27),control1:pt(0.69,0.26),control2:pt(0.64,0.25))
    p.addCurve(to:pt(0.50,0.29),control1:pt(0.55,0.28),control2:pt(0.53,0.30))
    p.addCurve(to:pt(0.40,0.27),control1:pt(0.46,0.30),control2:pt(0.45,0.28))
    p.addCurve(to:pt(0.28,0.30),control1:pt(0.36,0.25),control2:pt(0.31,0.26))
    p.addCurve(to:pt(0.18,0.52),control1:pt(0.24,0.33),control2:pt(0.20,0.40))
    p.addCurve(to:pt(0.28,0.69),control1:pt(0.14,0.62),control2:pt(0.16,0.71))
    p.addCurve(to:pt(0.50,0.67),control1:pt(0.34,0.72),control2:pt(0.43,0.74))
    p.closeSubpath();return p
}
func leaf(_ dx: CGFloat = 0,_ dy: CGFloat = 0) -> CGPath {
    let p=CGMutablePath()
    func pt(_ x:CGFloat,_ y:CGFloat)->CGPoint {point(x,y,shiftX:dx,shiftY:dy)}
    p.move(to:pt(0.48,0.72))
    p.addCurve(to:pt(0.73,0.87),control1:pt(0.53,0.86),control2:pt(0.61,0.88))
    p.addCurve(to:pt(0.48,0.72),control1:pt(0.70,0.76),control2:pt(0.61,0.70))
    p.closeSubpath();return p
}
func gradient(_ ctx:CGContext,_ path:CGPath,_ colors:[CGColor],_ start:CGPoint,_ end:CGPoint, stroke:CGColor? = nil, width:CGFloat = 0) {
    ctx.saveGState();ctx.addPath(path);ctx.clip()
    let g=CGGradient(colorsSpace:cs,colors:colors as CFArray,locations:nil)!
    ctx.drawLinearGradient(g,start:start,end:end,options:[]);ctx.restoreGState()
    if let stroke {ctx.setStrokeColor(stroke);ctx.setLineWidth(width);ctx.addPath(path);ctx.strokePath()}
}
let ctx=CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:size*4,space:cs,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
let rect=CGRect(x:0,y:0,width:size,height:size)
ctx.setFillColor(rgb(0.028,0.027,0.066));ctx.fill(rect)
let tile=CGPath(roundedRect:CGRect(x:48,y:48,width:928,height:928),cornerWidth:198,cornerHeight:198,transform:nil)
gradient(ctx,tile,[rgb(0.15,0.06,0.21),rgb(0.07,0.13,0.31),rgb(0.013,0.10,0.23)],point(0.1,0.95),point(0.9,0.04),stroke:rgb(0.65,0.76,1,0.45),width:9)
ctx.saveGState();ctx.addPath(tile);ctx.clip()
for (x,y,r,c) in [(0.13,0.75,0.42,rgb(0.99,0.16,0.58,0.17)),(0.81,0.28,0.43,rgb(0.0,0.60,1,0.17)),(0.52,0.52,0.45,rgb(0.50,0.15,0.99,0.10))] as [(CGFloat,CGFloat,CGFloat,CGColor)] {
 let g=CGGradient(colorsSpace:cs,colors:[c,rgb(0,0,0,0)] as CFArray,locations:[0,1])!
 ctx.drawRadialGradient(g,startCenter:point(x,y),startRadius:0,endCenter:point(x,y),endRadius:r*CGFloat(size),options:[])
}
ctx.restoreGState()
let layers:[(CGFloat,CGFloat,[CGColor],CGColor)] = [
 (48,-21,[rgb(0.05,0.75,1),rgb(0.02,0.24,0.88)],rgb(0.35,0.91,1,0.96)),
 (20,-9,[rgb(1,0.32,0.60),rgb(0.84,0.09,0.53)],rgb(1,0.65,0.86,0.9)),
 (-22,8,[rgb(1.0,0.76,0.88),rgb(0.58,0.42,0.94),rgb(0.07,0.63,0.97)],rgb(0.94,0.89,1,0.93))
]
for (i,layer) in layers.enumerated(){
 let p=apple(layer.0,layer.1)
 ctx.saveGState();ctx.setShadow(offset:CGSize(width:4,height:-3),blur:i==0 ? 43 : 18,color:layer.3)
 gradient(ctx,p,layer.2,point(0.28,0.80),point(0.79,0.16),stroke:layer.3,width:i==2 ? 10 : 8)
 ctx.restoreGState()
 let lf=leaf(layer.0,layer.1)
 gradient(ctx,lf,layer.2,point(0.47,0.91),point(0.78,0.65),stroke:layer.3,width:7)
}
let reflection=CGMutablePath()
reflection.move(to:point(0.27,0.61));reflection.addCurve(to:point(0.45,0.69),control1:point(0.31,0.72),control2:point(0.41,0.70))
reflection.addCurve(to:point(0.67,0.62),control1:point(0.55,0.70),control2:point(0.60,0.64))
ctx.saveGState();ctx.addPath(apple(-22,8));ctx.clip()
ctx.setStrokeColor(rgb(1,1,1,0.43));ctx.setLineWidth(14);ctx.addPath(reflection);ctx.strokePath();ctx.restoreGState()
ctx.addPath(tile);ctx.setStrokeColor(rgb(0.93,0.75,1.0,0.38));ctx.setLineWidth(5);ctx.strokePath()
if let cg=ctx.makeImage(){
 let bmp=NSBitmapImageRep(cgImage:cg)
 let dir="Resources/Branding"
 try! FileManager.default.createDirectory(atPath:dir,withIntermediateDirectories:true)
 let full=bmp.representation(using:.png,properties:[:])!
 try! full.write(to:URL(fileURLWithPath:dir+"/ManzanaRGB1024.png"))
 for name in ["AppIcon1024.png","AppIconDark1024.png","AppIconDark1024 1.png"]{
   let url=URL(fileURLWithPath:"Resources/Assets.xcassets/AppIcon.appiconset/"+name)
   try! full.write(to:url)
 }
 for (name,w,h) in [("AppIcon60x60@2x.png",120,120),("AppIcon76x76@2x~ipad.png",152,152)] {
   let small=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:w*4,bitsPerPixel:32)!
   if let c=NSGraphicsContext(bitmapImageRep:small){NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=c
     NSImage(cgImage:cg,size:NSSize(width:size,height:size)).draw(in:NSRect(x:0,y:0,width:w,height:h));c.flushGraphics();NSGraphicsContext.restoreGraphicsState()}
   try! small.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:dir+"/"+name))
 }
 print("Generated Manzana RGB app icon (1024 px, dark/tinted variants and legacy icon files)")
}
