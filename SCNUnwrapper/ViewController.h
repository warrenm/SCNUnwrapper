
#import <Cocoa/Cocoa.h>
#import <SceneKit/SceneKit.h>

@interface ViewController : NSViewController

@property (weak) IBOutlet SCNView *sceneKitView;
@property (weak) IBOutlet NSPopUpButton *shapePopUpButton;
@property (weak) IBOutlet NSImageView *unwrapImageView;
@property (weak) IBOutlet NSPopUpButton *elementPopUpButton;

@end

