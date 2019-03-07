
#import "ViewController.h"

@interface ViewController ()
@property (nonatomic, strong) NSArray<SCNGeometry *> *geometries;
@property (nonatomic, strong) SCNNode *shapeNode;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.sceneKitView.scene = [SCNScene scene];
    
    SCNNode *cameraNode = [SCNNode node];
    SCNCamera *camera = [SCNCamera camera];
    cameraNode.camera = camera;
    cameraNode.position = SCNVector3Make(2, 2, 2);
    [self.sceneKitView.scene.rootNode addChildNode:cameraNode];
    
    self.shapeNode = [SCNNode node];
    [self.sceneKitView.scene.rootNode addChildNode:self.shapeNode];

    self.sceneKitView.backgroundColor = NSColor.lightGrayColor;
    self.sceneKitView.allowsCameraControl = YES;
    self.sceneKitView.autoenablesDefaultLighting = YES;
    
    self.sceneKitView.pointOfView = cameraNode;
    [self.sceneKitView.pointOfView lookAt:SCNVector3Make(0, 0, 0)];

    SCNBox *box = [SCNBox boxWithWidth:0.75 height:1.0 length:0.75 chamferRadius:0.2];
    box.name = @"Box";

    SCNPyramid *pyramid = [SCNPyramid pyramidWithWidth:0.75 height:1.0 length:0.75];
    pyramid.name = @"Pyramid";

    SCNCone *cone = [SCNCone coneWithTopRadius:0.25 bottomRadius:0.75 height:1.0];
    cone.name = @"Cone";

    SCNTube *tube = [SCNTube tubeWithInnerRadius:0.25 outerRadius:0.75 height:1.0];
    tube.name = @"Tube";

    SCNCapsule *capsule = [SCNCapsule capsuleWithCapRadius:0.5 height:1.5];
    capsule.name = @"Capsule";

    SCNCylinder *cylinder = [SCNCylinder cylinderWithRadius:0.75 height:1.0];
    cylinder.name = @"Cylinder";

    SCNSphere *sphere = [SCNSphere sphereWithRadius:0.75];
    sphere.name = @"Sphere";

    SCNSphere *geodesic = [SCNSphere sphereWithRadius:0.75];
    geodesic.name = @"Sphere (Geodesic)";
    geodesic.geodesic = YES;

    SCNTorus *torus = [SCNTorus torusWithRingRadius:0.75 pipeRadius:0.25];
    torus.name = @"Torus";

    SCNPlane *plane = [SCNPlane planeWithWidth:0.75 height:0.75];
    plane.name = @"Plane";

    SCNText *text = [SCNText textWithString:@"SCN" extrusionDepth:15.0];
    text.name = @"Text";
    text.chamferRadius = 1.0;
    
    self.geometries = @[ box, pyramid, cone, tube, capsule, cylinder, sphere, geodesic, torus, plane, text];
    
    NSMutableArray *buttonTitles = [NSMutableArray array];
    [self.geometries enumerateObjectsUsingBlock:^(SCNGeometry *obj, NSUInteger idx, BOOL *stop) {
        [buttonTitles addObject:obj.name ?: @"(unnamed)"];
    }];

//    [self.shapePopUpButton removeAllItems];
    [self.shapePopUpButton addItemsWithTitles:buttonTitles];
    
    [self selectedShapeDidChange:self];
}

- (IBAction)selectedShapeDidChange:(id)sender {
    self.shapeNode.geometry = self.geometries[self.shapePopUpButton.indexOfSelectedItem];
    [self.shapeNode.geometry removeMaterialAtIndex:0];
    for (int i = 1; i <= 6; ++i) {
        [self.shapeNode.geometry insertMaterial:[SCNMaterial material] atIndex:(i-1)];
        self.shapeNode.geometry.materials[i - 1].diffuse.contents = [NSString stringWithFormat:@"%d.png", i];
    }
    
    if ([self.shapeNode.geometry isKindOfClass:[SCNText class]]) {
        CGFloat textScale = 1/50.0;
        self.shapeNode.scale = SCNVector3Make(textScale, textScale, textScale);
    } else {
        self.shapeNode.scale = SCNVector3Make(1, 1, 1);
    }
    
    [self.elementPopUpButton removeAllItems];
    NSMutableArray *elementTitles = [NSMutableArray array];
    for (int i = 1; i <= self.shapeNode.geometry.geometryElements.count; ++i) {
        [elementTitles addObject:[NSString stringWithFormat:@"%d", i]];
    }
    [self.elementPopUpButton addItemsWithTitles:elementTitles];
    
    [self selectedElementDidChange:self];
}

- (IBAction)selectedElementDidChange:(id)sender {
    NSInteger elementIndex = [self.elementPopUpButton indexOfSelectedItem];
    SCNGeometry *uvGeometry = [self upwrapGeometry:self.shapeNode.geometry];
    NSImage *uvImage = [self uvImageForUnwrappedGeometry:uvGeometry elementIndex:elementIndex];
    [self.unwrapImageView setImage:uvImage];
//    uvGeometry.materials[elementIndex].diffuse.contents = uvImage;
}

- (SCNGeometry *)upwrapGeometry:(SCNGeometry *)geometry
{
    NSMutableArray<SCNGeometrySource *> *sources = [NSMutableArray array];
    for (SCNGeometrySource *source in geometry.geometrySources) {
        if ([source.semantic isEqualToString:SCNGeometrySourceSemanticVertex]) {
            SCNGeometrySource *uvSource = [[geometry geometrySourcesForSemantic:SCNGeometrySourceSemanticTexcoord] firstObject];
            NSAssert(uvSource != nil, @"Could not find tex coord source in geometry to flatten from");
            const char *uvData = uvSource.data.bytes + uvSource.dataOffset;
            SCNVector3 *uvVertices = (SCNVector3 *)malloc(sizeof(SCNVector3) * uvSource.vectorCount);
            for (int i = 0; i < uvSource.vectorCount; ++i) {
                float *uv = (float *)(uvData + (uvSource.dataStride * i));
                uvVertices[i] = SCNVector3Make(uv[0], uv[1], 0);
            }
            [sources addObject:[SCNGeometrySource geometrySourceWithVertices:uvVertices count:source.vectorCount]];
            free(uvVertices);
        } else {
            [sources addObject:[SCNGeometrySource geometrySourceWithData:source.data
                                                                semantic:source.semantic
                                                             vectorCount:source.vectorCount
                                                         floatComponents:source.floatComponents
                                                     componentsPerVector:source.componentsPerVector
                                                       bytesPerComponent:source.bytesPerComponent
                                                              dataOffset:source.dataOffset
                                                              dataStride:source.dataStride]];
        }
    }
    NSMutableArray<SCNGeometryElement *> *elements = [NSMutableArray array];
    for (SCNGeometryElement *element in geometry.geometryElements) {
        [elements addObject:[SCNGeometryElement geometryElementWithData:element.data
                                                          primitiveType:element.primitiveType
                                                         primitiveCount:element.primitiveCount
                                                          bytesPerIndex:element.bytesPerIndex]];
    }
    SCNGeometry *uvGeometry = [SCNGeometry geometryWithSources:sources elements:elements];
    uvGeometry.materials = geometry.materials;
    return uvGeometry;
}

- (NSImage *)uvImageForUnwrappedGeometry:(SCNGeometry *)geometry elementIndex:(NSInteger)elementIndex
{
    SCNGeometryElement *element = [geometry geometryElementAtIndex:elementIndex];
    SCNGeometrySource *vertexSource = [[geometry geometrySourcesForSemantic:SCNGeometrySourceSemanticVertex] firstObject];

    const char *indexData = element.data.bytes;
    const char *vertexData = vertexSource.data.bytes + vertexSource.dataOffset;
    
    SCNMaterial *material = geometry.materials[elementIndex % geometry.materials.count];
    
    NSString *materialImageName = material.diffuse.contents;
    
    if (![materialImageName isKindOfClass:[NSString class]]) { return nil; }
    
    NSImage *materialImage = [NSImage imageNamed:materialImageName];

    CGFloat side = 256;
    NSSize size = NSMakeSize(side, side);
    
    NSImage* im = [[NSImage alloc] initWithSize:size];
    NSBitmapImageRep* rep = [[NSBitmapImageRep alloc]
                             initWithBitmapDataPlanes:NULL
                             pixelsWide:size.width
                             pixelsHigh:size.height
                             bitsPerSample:8
                             samplesPerPixel:4
                             hasAlpha:YES
                             isPlanar:NO
                             colorSpaceName:NSCalibratedRGBColorSpace
                             bytesPerRow:0
                             bitsPerPixel:0];
    
    [im addRepresentation:rep];
    
    [im lockFocus];
    
    NSRect imageRect = NSMakeRect(0, 0, size.width, size.height);
    
    [materialImage drawInRect:imageRect];
    
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    CGContextScaleCTM(context, 1, -1);
    CGContextTranslateCTM(context, 0, -size.height);
    
    UInt16 *shortIndices = (UInt16 *)indexData;
    UInt32 *intIndices = (UInt32 *)indexData;
    
    NSAssert(element.primitiveType == SCNGeometryPrimitiveTypeTriangles, @"Can only unwrap triangle soup");

    for (int i = 0; i < element.primitiveCount; ++i) {
        UInt32 i0 = (element.bytesPerIndex == 2) ? shortIndices[i * 3 + 0] : intIndices[i * 3 + 0];
        UInt32 i1 = (element.bytesPerIndex == 2) ? shortIndices[i * 3 + 1] : intIndices[i * 3 + 1];
        UInt32 i2 = (element.bytesPerIndex == 2) ? shortIndices[i * 3 + 2] : intIndices[i * 3 + 2];

        float *v0 = (float *)(vertexData + vertexSource.dataStride * i0);
        float *v1 = (float *)(vertexData + vertexSource.dataStride * i1);
        float *v2 = (float *)(vertexData + vertexSource.dataStride * i2);
        CGContextMoveToPoint(context, v0[0] * size.width, v0[1] * size.height);
        CGContextAddLineToPoint(context, v1[0] * size.width, v1[1] * size.height);
        CGContextAddLineToPoint(context, v2[0] * size.width, v2[1] * size.height);
        CGContextAddLineToPoint(context, v0[0] * size.width, v0[1] * size.height);
    }
    
    CGContextSetRGBStrokeColor(context, 0, 0.9, 0, 1.0);
    CGContextStrokePath(context);
    
    [im unlockFocus];

    return im;
}

@end
