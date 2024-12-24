#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Metal/Metal.h>
#import "Yolo.h"

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) UIImage *latestFrame;  // Property to store the most recent frame
@property (nonatomic, strong) UILabel *fpsLabel;  // Label to display the FPS
@property (nonatomic, assign) CFTimeInterval lastFrameTime;  // Time when the last frame was captured
@property (nonatomic, assign) NSUInteger frameCount;  // Number of frames captured
@property (nonatomic, strong) Yolo *yolo;
- (NSArray *)processOutput:(const float *)output outputLength:(int)outputLength imgWidth:(float)imgWidth imgHeight:(float)imgHeight;

@end

@implementation ViewController

CFDataRef data;
NSMutableArray *_q;
NSMutableDictionary *_h;
NSMutableDictionary *classColorMap;
NSString *input_buffer;
NSString *output_buffer;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.yolo = [[Yolo alloc] init];
    [self setupYOLO];
    [self setupCamera];
    [self setupFPSLabel];
    self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
}

- (void)setupYOLO {
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:[NSString stringWithFormat:@"batch_req_%dx%d", self.yolo.yolo_res, self.yolo.yolo_res]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://raw.githubusercontent.com/roryclear/yolov8-tinygrad-ios/main/batch_req_%dx%d",self.yolo.yolo_res,self.yolo.yolo_res]]];
        [data writeToFile:filePath atomically:YES];
    }
    NSData *ns_data = [NSData dataWithContentsOfFile:filePath];
    data = CFDataCreate(NULL, [ns_data bytes], [ns_data length]);
    
    const UInt8 *bytes = CFDataGetBytePtr(data);
    NSInteger length = CFDataGetLength(data);

    NSData *range_data;
    _h = [[NSMutableDictionary alloc] init];
    NSInteger ptr = 0;
    NSString *string_data;
    NSMutableString *datahash = [NSMutableString stringWithCapacity:0x40];
    while (ptr < length) {
        NSData *slicedData = [NSData dataWithBytes:bytes + ptr + 0x20 length:0x28 - 0x20];
        uint64_t datalen = 0;
        [slicedData getBytes:&datalen length:sizeof(datalen)];
        datalen = CFSwapInt64LittleToHost(datalen);
        const UInt8 *datahash_bytes = bytes + ptr;
        datahash = [NSMutableString stringWithCapacity:0x40];
        for (int i = 0; i < 0x20; i++) {
            [datahash appendFormat:@"%02x", datahash_bytes[i]];
        }
        range_data = [NSData dataWithBytes:bytes + (ptr + 0x28) length:datalen];
        _h[datahash] = range_data;
        ptr += 0x28 + datalen;
    }
    CFRelease(data);
    string_data = [[NSString alloc] initWithData:range_data encoding:NSUTF8StringEncoding];
    _q = [NSMutableArray array];
    NSMutableArray *_q_exec = [NSMutableArray array];
    NSArray *ops = @[@"BufferAlloc", @"CopyIn", @"ProgramAlloc",@"ProgramExec",@"CopyOut"];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"(%@)\\(", [ops componentsJoinedByString:@"|"]] options:0 error:nil];
    __block NSInteger lastIndex = 0;
    [regex enumerateMatchesInString:string_data options:0 range:NSMakeRange(0, string_data.length) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        [_q addObject:[self.yolo extractValues:([[string_data substringWithRange:NSMakeRange(lastIndex, match.range.location - lastIndex)] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]])]];
        lastIndex = match.range.location;
    }];
    [_q addObject:[self.yolo extractValues:([[string_data substringFromIndex:lastIndex] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]])]];
    for (NSMutableDictionary *values in _q) {
        if ([values[@"op"] isEqualToString:@"BufferAlloc"]) {
            [self.yolo.buffers setObject:[self.yolo.device newBufferWithLength:[values[@"size"][0] intValue] options:MTLResourceStorageModeShared] forKey:values[@"buffer_num"][0]];
        } else if ([values[@"op"] isEqualToString:@"CopyIn"]) {
            id<MTLBuffer> buffer = self.yolo.buffers[values[@"buffer_num"][0]];
            NSData *data = _h[values[@"datahash"][0]];
            memcpy(buffer.contents, data.bytes, data.length);
            input_buffer = values[@"buffer_num"][0];
        } else if ([values[@"op"] isEqualToString:@"ProgramAlloc"]) {
            if ([self.yolo.pipeline_states objectForKey:@[values[@"name"][0],values[@"datahash"][0]]]) continue;
            NSString *prg = [[NSString alloc] initWithData:_h[values[@"datahash"][0]] encoding:NSUTF8StringEncoding];
            NSError *error = nil;
            id<MTLLibrary> library = [self.yolo.device newLibraryWithSource:prg
                                                          options:nil
                                                            error:&error];
            MTLComputePipelineDescriptor *descriptor = [[MTLComputePipelineDescriptor alloc] init];
            descriptor.computeFunction = [library newFunctionWithName:values[@"name"][0]];;
            descriptor.supportIndirectCommandBuffers = YES;
            MTLComputePipelineReflection *reflection = nil;
            id<MTLComputePipelineState> pipeline_state = [self.yolo.device newComputePipelineStateWithDescriptor:descriptor
                                                                                               options:MTLPipelineOptionNone
                                                                                            reflection:&reflection
                                                                                                 error:&error];
            [self.yolo.pipeline_states setObject:pipeline_state forKey:@[values[@"name"][0],values[@"datahash"][0]]];
        } else if ([values[@"op"] isEqualToString:@"ProgramExec"]) {
            [_q_exec addObject:values];
        } else if ([values[@"op"] isEqualToString:@"CopyOut"]) {
            output_buffer = values[@"buffer_num"][0];
        }
    }
    _q = [_q_exec mutableCopy];
    [_h removeAllObjects];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.captureSession stopRunning];
    if (self.latestFrame) {
        CGImageRelease(self.latestFrame.CGImage);
    }
}

#pragma mark - Camera Setup
- (void)setupCamera {
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
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
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view.layer addSublayer:self.previewLayer];
    [self.captureSession startRunning];
}

- (NSArray *)processOutput:(const float *)output outputLength:(int)outputLength imgWidth:(float)imgWidth imgHeight:(float)imgHeight {
    NSMutableArray *boxes = [NSMutableArray array];
    int modelInputSize = self.yolo.yolo_res;
    int numPredictions = pow(modelInputSize / 32, 2) * 21;

    for (int index = 0; index < numPredictions; index++) {
        int classId = 0;
        float prob = 0.0;

        for (int col = 0; col < self.yolo.yolo_classes.count; col++) {
            float confidence = output[numPredictions * (col + 4) + index];
            if (confidence > prob) {
                prob = confidence;
                classId = col;
            }
        }

        if (prob < 0.25) continue;

        float xc = output[index];
        float yc = output[numPredictions + index];
        float w = output[2 * numPredictions + index];
        float h = output[3 * numPredictions + index];

        float x1 = (xc - w / 2) / modelInputSize * imgWidth;
        float y1 = (yc - h / 2) / modelInputSize * imgHeight;
        float x2 = (xc + w / 2) / modelInputSize * imgWidth;
        float y2 = (yc + h / 2) / modelInputSize * imgHeight;

        [boxes addObject:@[@(x1), @(y1), @(x2), @(y2), @(classId), @(prob)]];
    }

    [boxes sortUsingComparator:^NSComparisonResult(NSArray *box1, NSArray *box2) {
        NSNumber *prob1 = box1[5];
        NSNumber *prob2 = box2[5];
        return [prob2 compare:prob1];
    }];

    NSMutableArray *result = [NSMutableArray array];
    while ([boxes count] > 0) {
        NSArray *bestBox = boxes[0];
        [result addObject:bestBox];
        [boxes removeObjectAtIndex:0];

        NSMutableArray *filteredBoxes = [NSMutableArray array];
        for (NSArray *box in boxes) {
            if ([self.yolo iouBetweenBox:bestBox andBox:box] < 0.7) {
                [filteredBoxes addObject:box];
            }
        }
        boxes = filteredBoxes;
    }
    return [result copy];
}

- (void)drawSquareWithTopLeftX:(CGFloat)xOrigin topLeftY:(CGFloat)yOrigin bottomRightX:(CGFloat)bottomRightX bottomRightY:(CGFloat)bottomRightY classIndex:(int)classIndex aspectRatio:(float)aspectRatio {
    CGFloat minDimension = MIN(self.view.bounds.size.width, self.view.bounds.size.height);
    CGFloat height = self.yolo.yolo_res / aspectRatio;
    CGFloat leftEdgeX = (self.view.bounds.size.width - (minDimension * aspectRatio)) / 2;
    CGFloat scaledXOrigin = leftEdgeX + (xOrigin * aspectRatio / self.yolo.yolo_res) * minDimension;
    CGFloat scaledYOrigin = (yOrigin / height) * minDimension;
    CGFloat scaledWidth = (bottomRightX - xOrigin) * (aspectRatio * minDimension / self.yolo.yolo_res);
    CGFloat scaledHeight = (bottomRightY - yOrigin) * (minDimension / height);
    UIColor *color = self.yolo.yolo_classes[classIndex][1];
    CAShapeLayer *squareLayer = [CAShapeLayer layer];
    squareLayer.name = @"rectangleLayer";
    squareLayer.strokeColor = color.CGColor;
    squareLayer.lineWidth = 2.0;
    squareLayer.fillColor = [UIColor clearColor].CGColor;
    squareLayer.path = [UIBezierPath bezierPathWithRect:CGRectMake(scaledXOrigin, scaledYOrigin, scaledWidth, scaledHeight)].CGPath;
    
    [self.view.layer addSublayer:squareLayer];
    
    NSString *className = self.yolo.yolo_classes[classIndex][0];
    NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:12],
                                     NSForegroundColorAttributeName: [UIColor whiteColor]};
    NSString *labelText = [className lowercaseString];
    CGSize textSize = [labelText sizeWithAttributes:textAttributes];
    
    CGFloat labelX = scaledXOrigin - 2;
    CGFloat labelY = scaledYOrigin - textSize.height - 2;
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(labelX, labelY, textSize.width + 4, textSize.height + 2)];
    label.backgroundColor = color;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:12];
    label.text = labelText;
    
    [self.view addSubview:label];
}

- (void)resetSquares {
    NSMutableArray *layersToRemove = [NSMutableArray array];
    NSMutableArray *labelsToRemove = [NSMutableArray array];

    for (CALayer *layer in self.view.layer.sublayers) {
        if ([layer.name isEqualToString:@"rectangleLayer"]) {
            [layersToRemove addObject:layer];
        }
    }
    
    for (UIView *subview in self.view.subviews) {
        if ([subview isKindOfClass:[UILabel class]] && subview != self.fpsLabel) {
            [labelsToRemove addObject:subview];
        }
    }
    
    for (CALayer *layer in layersToRemove) {
        [layer removeFromSuperlayer];
    }
    
    for (UIView *label in labelsToRemove) {
        [label removeFromSuperview];
    }
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
    self.previewLayer.frame = [self frameForCurrentOrientation];
}

- (CGRect)frameForCurrentOrientation {
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    return CGRectMake(0, 0, width, height);
}

- (CGImageRef)cropAndResizeCGImage:(CGImageRef)image toSize:(CGSize)size {
    CGFloat originalWidth = CGImageGetWidth(image);
    CGFloat originalHeight = CGImageGetHeight(image);
    CGFloat sideLength = MIN(originalWidth, originalHeight);
    CGRect cropRect = CGRectMake((originalWidth - sideLength) / 2.0,
                                 (originalHeight - sideLength) / 2.0,
                                 sideLength,
                                 sideLength);

    CGImageRef croppedImageRef = CGImageCreateWithImageInRect(image, cropRect);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [[UIImage imageWithCGImage:croppedImageRef] drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGImageRelease(croppedImageRef);

    return resizedImage.CGImage;
}

- (NSArray *)yolo:(CGImageRef)cgImage {
    CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
    const UInt8 *rawBytes = CFDataGetBytePtr(rawData);
    size_t length = CFDataGetLength(rawData);
    size_t rgbLength = (length / 4) * 3;
    UInt8 *rgbData = (UInt8 *)malloc(rgbLength);
    //RGBA to RGB
    for (size_t i = 0, j = 0; i < length; i += 4, j += 3) {
        rgbData[j] = rawBytes[i];
        rgbData[j + 1] = rawBytes[i + 1];
        rgbData[j + 2] = rawBytes[i + 2];
    }
    id<MTLBuffer> buffer = self.yolo.buffers[input_buffer];
    memset(buffer.contents, 0, buffer.length);
    memcpy(buffer.contents, rgbData, rgbLength);
    free(rgbData);
    CFRelease(rawData);
    
    for (NSMutableDictionary *values in _q) {
        id<MTLCommandBuffer> command_buffer = [self.yolo.mtl_queue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [command_buffer computeCommandEncoder];
        [encoder setComputePipelineState:self.yolo.pipeline_states[@[values[@"name"][0],values[@"datahash"][0]]]];
        for(int i = 0; i < [(NSArray *)values[@"bufs"] count]; i++){
            [encoder setBuffer:self.yolo.buffers[values[@"bufs"][i]] offset:0 atIndex:i];
        }
        for (int i = 0; i < [(NSArray *)values[@"vals"] count]; i++) {
            NSInteger value = [values[@"vals"][i] integerValue];
            [encoder setBytes:&value length:sizeof(NSInteger) atIndex:i + [(NSArray *)values[@"bufs"] count]];
        }
        MTLSize global_size = MTLSizeMake([values[@"global_sizes"][0] intValue], [values[@"global_sizes"][1] intValue], [values[@"global_sizes"][2] intValue]);
        MTLSize local_size = MTLSizeMake([values[@"local_sizes"][0] intValue], [values[@"local_sizes"][1] intValue], [values[@"local_sizes"][2] intValue]);
        [encoder dispatchThreadgroups:global_size threadsPerThreadgroup:local_size];
        [encoder endEncoding];
        [command_buffer commit];
        [self.yolo.mtl_buffers_in_flight addObject: command_buffer];
    }

    for(int i = 0; i < self.yolo.mtl_buffers_in_flight.count; i++){
        [self.yolo.mtl_buffers_in_flight[i] waitUntilCompleted];
    }
    [self.yolo.mtl_buffers_in_flight removeAllObjects];
    buffer = self.yolo.buffers[output_buffer];
    const void *bufferPointer = buffer.contents;
    float *floatArray = malloc(buffer.length);
    memcpy(floatArray, bufferPointer, buffer.length);
    NSArray *output = [self processOutput:floatArray outputLength:buffer.length / 4 imgWidth:self.yolo.yolo_res imgHeight:self.yolo.yolo_res];
    NSMutableString *classNamesString = [NSMutableString string];
    for (int i = 0; i < output.count; i++) {
        //uiImage = drawSquareOnImage(uiImage, [output[i][0] floatValue], [output[i][1] floatValue], [output[i][2] floatValue], [output[i][3] floatValue], [output[i][4] intValue]);
        [classNamesString appendString:self.yolo.yolo_classes[[output[i][4] intValue]][0]];
        if (i < output.count - 1) [classNamesString appendString:@", "];
    }
    NSLog(@"Class Names: %@", classNamesString);
    free(floatArray);
    return output;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGFloat aspect_ratio = (CGFloat)width / (CGFloat)height;
    CGFloat targetWidth = self.yolo.yolo_res;
    CGFloat aspectRatio = (CGFloat)width / (CGFloat)height;
    CGSize targetSize = CGSizeMake(targetWidth, targetWidth / aspectRatio);

    CGFloat scaleX = targetSize.width / width;
    CGFloat scaleY = targetSize.height / height;
    CIImage *resizedImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeScale(scaleX, scaleY)];

    CGRect cropRect = CGRectMake(0, 0, targetSize.width, targetSize.height);
    CIImage *croppedImage = [resizedImage imageByCroppingToRect:cropRect];

    CIContext *context = [CIContext context];
    CGImageRef cgImage = [context createCGImage:croppedImage fromRect:cropRect];
    self.latestFrame = [UIImage imageWithCGImage:cgImage];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *output = [self yolo:cgImage];
        CGImageRelease(cgImage);

        [self resetSquares];
        for (int i = 0; i < output.count; i++) {
            [self drawSquareWithTopLeftX:[output[i][0] floatValue]
                                topLeftY:[output[i][1] floatValue]
                            bottomRightX:[output[i][2] floatValue]
                            bottomRightY:[output[i][3] floatValue]
                              classIndex:[output[i][4] intValue]
                             aspectRatio:aspect_ratio];
        }
    });
    [self updateFPS];
}

#pragma mark - Update FPS
- (void)updateFPS {
    CFTimeInterval currentTime = CACurrentMediaTime();
    if (self.lastFrameTime > 0) {
        CFTimeInterval deltaTime = currentTime - self.lastFrameTime;
        self.frameCount++;
        if (deltaTime >= 1.0) {
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
