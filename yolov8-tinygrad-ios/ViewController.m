#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupCamera];
}

#pragma mark - Camera Setup

- (void)setupCamera {
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    
    // Configure camera input
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        NSLog(@"Error setting up camera input: %@", error.localizedDescription);
        return;
    }
    [self.captureSession addInput:input];
    
    // Configure preview layer
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect; // Maintain aspect ratio without cropping
    [self.view.layer addSublayer:self.previewLayer];
    
    // Start the camera session
    [self.captureSession startRunning];
}

#pragma mark - Handle Rotation

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    // Update the frame of the preview layer
    self.previewLayer.frame = [self frameForCurrentOrientation];
    
    // Update video orientation
    self.previewLayer.connection.videoOrientation = [self videoOrientationForDeviceOrientation:[[UIDevice currentDevice] orientation]];
}

- (CGRect)frameForCurrentOrientation {
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    
    // Match the preview layer's frame to the screen size
    return CGRectMake(0, 0, width, height);
}

- (AVCaptureVideoOrientation)videoOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation {
    switch (deviceOrientation) {
        case UIDeviceOrientationPortrait:
            return AVCaptureVideoOrientationPortrait;
        case UIDeviceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeRight; // Opposite for camera
        case UIDeviceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeLeft; // Opposite for camera
        case UIDeviceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
        default:
            return AVCaptureVideoOrientationPortrait;
    }
}

#pragma mark - Memory Management

- (void)dealloc {
    [self.captureSession stopRunning];
}

@end


