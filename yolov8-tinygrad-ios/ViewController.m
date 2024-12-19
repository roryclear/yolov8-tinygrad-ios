#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) UIImage *latestFrame;  // Property to store the most recent frame
@property (nonatomic, strong) UILabel *fpsLabel;  // Label to display the FPS
@property (nonatomic, assign) CFTimeInterval lastFrameTime;  // Time when the last frame was captured
@property (nonatomic, assign) NSUInteger frameCount;  // Number of frames captured
@property (nonatomic, assign) AVCaptureVideoOrientation currentOrientation;  // Keep track of the current orientation

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupCamera];
    [self setupFPSLabel];
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
    self.captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
    
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

#pragma mark - Setup FPS Label

- (void)setupFPSLabel {
    self.fpsLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 30, 150, 30)];
    self.fpsLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    self.fpsLabel.textColor = [UIColor whiteColor];
    self.fpsLabel.font = [UIFont boldSystemFontOfSize:18];
    self.fpsLabel.text = @"FPS: 0";
    [self.view addSubview:self.fpsLabel];
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

- (UIImage *)cropAndResizeImage:(UIImage *)image toSize:(CGSize)size {
    CGFloat sideLength = MIN(image.size.width, image.size.height);
    CGRect cropRect = CGRectMake((image.size.width - sideLength) / 2.0,
                                 (image.size.height - sideLength) / 2.0,
                                 sideLength,
                                 sideLength);

    CGImageRef croppedImageRef = CGImageCreateWithImageInRect(image.CGImage, cropRect);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [[UIImage imageWithCGImage:croppedImageRef] drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGImageRelease(croppedImageRef);

    return resizedImage;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];
    
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:ciImage fromRect:ciImage.extent];
    
    //self.latestFrame = [UIImage imageWithCGImage:cgImage];
    UIImage *originalImage = [UIImage imageWithCGImage:cgImage];
    self.latestFrame = [self cropAndResizeImage:originalImage toSize:CGSizeMake(640, 640)];
    
    CGImageRelease(cgImage);
    //usleep(100000);
    
    // Update FPS
    [self updateFPS];
}

#pragma mark - Update FPS

- (void)updateFPS {
    CFTimeInterval currentTime = CACurrentMediaTime();
    if (self.lastFrameTime > 0) {
        CFTimeInterval deltaTime = currentTime - self.lastFrameTime;
        self.frameCount++;
        if (deltaTime >= 1.0) { // Update FPS every second
            CGFloat fps = self.frameCount / deltaTime;
            self.fpsLabel.text = [NSString stringWithFormat:@"FPS: %.1f", fps];
            self.frameCount = 0;
            self.lastFrameTime = currentTime;
        }
    } else {
        self.lastFrameTime = currentTime;
    }
}

@end

