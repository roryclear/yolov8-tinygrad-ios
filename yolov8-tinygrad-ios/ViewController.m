#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) UIImage *latestFrame;  // Property to store the most recent frame
@property (nonatomic, assign) AVCaptureVideoOrientation currentOrientation;  // Keep track of the current orientation

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupCamera];
    [self setupNotification];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.captureSession stopRunning];
    if (self.latestFrame) {
        CGImageRelease(self.latestFrame.CGImage);
    }
}

#pragma mark - Setup Notification

- (void)setupNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleOrientationChange) name:UIDeviceOrientationDidChangeNotification object:nil];
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
    
    // Configure video data output
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    output.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    output.alwaysDiscardsLateVideoFrames = YES;
    [output setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    [self.captureSession addOutput:output];
    
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
    [self updateCameraOrientation];
}

- (CGRect)frameForCurrentOrientation {
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    
    // Match the preview layer's frame to the screen size
    return CGRectMake(0, 0, width, height);
}

- (void)handleOrientationChange {
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    AVCaptureVideoOrientation newOrientation = [self videoOrientationForDeviceOrientation:deviceOrientation];
    
    // Only update orientation if it's different from the current orientation
    if (newOrientation != self.currentOrientation) {
        self.currentOrientation = newOrientation;
        [self updateCameraOrientation];
    }
}

- (AVCaptureVideoOrientation)videoOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation {
    switch (deviceOrientation) {
        case UIDeviceOrientationPortrait:
            return AVCaptureVideoOrientationPortrait;
        case UIDeviceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeRight; // Opposite for camera
        case UIDeviceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeLeft; // Opposite for camera
        default:
            return self.currentOrientation;  // Keep the current orientation if unknown
    }
}

- (void)updateCameraOrientation {
    AVCaptureConnection *connection = self.previewLayer.connection;
    if ([connection isVideoOrientationSupported]) {
        connection.videoOrientation = self.currentOrientation;
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];
    
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:ciImage fromRect:ciImage.extent];
    
    self.latestFrame = [UIImage imageWithCGImage:cgImage];  // Store the most recent frame as a UIImage
    
    CGImageRelease(cgImage);
}

@end

