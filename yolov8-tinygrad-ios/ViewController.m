#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *fpsLabel;
@property (nonatomic, assign) uint8_t *pixelArray;
@property (nonatomic, assign) NSUInteger totalBytes;
@property (nonatomic, assign) CFTimeInterval lastFrameTime;
@property (nonatomic, assign) NSUInteger frameCount;

@end

@implementation ViewController

id<MTLDevice> device;
NSMutableDictionary<NSString *, id> *pipeline_states;
NSMutableDictionary<NSString *, id> *buffers;
NSMutableArray<id<MTLCommandBuffer>> *mtl_buffers_in_flight;
id<MTLCommandQueue> mtl_queue;
CFDataRef data;
NSMutableArray *_q;
NSMutableDictionary *_h;
NSMutableDictionary *classColorMap;
NSArray *yolo_classes;

- (void)viewDidLoad {
    [super viewDidLoad];
    pipeline_states = [[NSMutableDictionary alloc] init];
    buffers = [[NSMutableDictionary alloc] init];
    device = MTLCreateSystemDefaultDevice();
    mtl_queue = [device newCommandQueueWithMaxCommandBufferCount:1024];
    mtl_buffers_in_flight = [[NSMutableArray alloc] init];
    
    yolo_classes = @[
        @"person", @"bicycle", @"car", @"motorcycle", @"airplane", @"bus", @"train", @"truck", @"boat",
        @"traffic light", @"fire hydrant", @"stop sign", @"parking meter", @"bench", @"bird", @"cat", @"dog", @"horse",
        @"sheep", @"cow", @"elephant", @"bear", @"zebra", @"giraffe", @"backpack", @"umbrella", @"handbag", @"tie", @"suitcase",
        @"frisbee", @"skis", @"snowboard", @"sports ball", @"kite", @"baseball bat", @"baseball glove", @"skateboard",
        @"surfboard", @"tennis racket", @"bottle", @"wine glass", @"cup", @"fork", @"knife", @"spoon", @"bowl", @"banana", @"apple",
        @"sandwich", @"orange", @"broccoli", @"carrot", @"hot dog", @"pizza", @"donut", @"cake", @"chair", @"couch", @"potted plant",
        @"bed", @"dining table", @"toilet", @"tv", @"laptop", @"mouse", @"remote", @"keyboard", @"cell phone", @"microwave", @"oven",
        @"toaster", @"sink", @"refrigerator", @"book", @"clock", @"vase", @"scissors", @"teddy bear", @"hair drier", @"toothbrush"
    ];
    
    classColorMap = @{
        @"person": [UIColor redColor],
        @"bicycle": [UIColor greenColor],
        @"car": [UIColor blueColor],
        @"motorcycle": [UIColor cyanColor],
        @"airplane": [UIColor magentaColor],
        @"bus": [UIColor yellowColor],
        @"train": [UIColor orangeColor],
        @"truck": [UIColor purpleColor],
        @"boat": [UIColor brownColor],
        @"traffic light": [UIColor lightGrayColor],
        @"fire hydrant": [UIColor darkGrayColor],
        @"stop sign": [UIColor whiteColor],
        @"parking meter": [UIColor blackColor],
        @"bench": [UIColor grayColor],
        @"bird": [UIColor darkTextColor],
        @"cat": [UIColor lightTextColor],
        @"dog": [UIColor systemPinkColor],
        @"horse": [UIColor systemTealColor],
        @"sheep": [UIColor systemIndigoColor],
        @"cow": [UIColor systemYellowColor],
        @"elephant": [UIColor systemPurpleColor],
        @"bear": [UIColor systemGreenColor],
        @"zebra": [UIColor systemBlueColor],
        @"giraffe": [UIColor systemOrangeColor],
        @"backpack": [UIColor systemRedColor],
        @"umbrella": [UIColor systemBrownColor],
        @"handbag": [UIColor systemCyanColor],
        @"tie": [UIColor systemMintColor],
        @"suitcase": [UIColor systemPurpleColor],
        @"frisbee": [UIColor systemPinkColor],
        @"skis": [UIColor systemGreenColor],
        @"snowboard": [UIColor systemYellowColor],
        @"sports ball": [UIColor systemOrangeColor],
        @"kite": [UIColor systemRedColor],
        @"baseball bat": [UIColor systemPinkColor],
        @"baseball glove": [UIColor systemPurpleColor],
        @"skateboard": [UIColor systemCyanColor],
        @"surfboard": [UIColor systemMintColor],
        @"tennis racket": [UIColor systemTealColor],
        @"bottle": [UIColor systemIndigoColor],
        @"wine glass": [UIColor systemYellowColor],
        @"cup": [UIColor systemRedColor],
        @"fork": [UIColor systemGreenColor],
        @"knife": [UIColor systemCyanColor],
        @"spoon": [UIColor systemOrangeColor],
        @"bowl": [UIColor systemPurpleColor],
        @"banana": [UIColor systemYellowColor],
        @"apple": [UIColor systemRedColor],
        @"sandwich": [UIColor systemBrownColor],
        @"orange": [UIColor systemOrangeColor],
        @"broccoli": [UIColor systemGreenColor],
        @"carrot": [UIColor systemOrangeColor],
        @"hot dog": [UIColor systemPinkColor],
        @"pizza": [UIColor systemRedColor],
        @"donut": [UIColor systemPurpleColor],
        @"cake": [UIColor systemYellowColor],
        @"chair": [UIColor systemBrownColor],
        @"couch": [UIColor systemOrangeColor],
        @"potted plant": [UIColor systemGreenColor],
        @"bed": [UIColor systemRedColor],
        @"dining table": [UIColor systemPurpleColor],
        @"toilet": [UIColor systemGrayColor],
        @"tv": [UIColor systemBlueColor],
        @"laptop": [UIColor systemPurpleColor],
        @"mouse": [UIColor systemRedColor],
        @"remote": [UIColor systemGrayColor],
        @"keyboard": [UIColor systemYellowColor],
        @"cell phone": [UIColor systemGreenColor],
        @"microwave": [UIColor systemBlueColor],
        @"oven": [UIColor systemOrangeColor],
        @"toaster": [UIColor systemBrownColor],
        @"sink": [UIColor systemGrayColor],
        @"refrigerator": [UIColor systemTealColor],
        @"book": [UIColor systemRedColor],
        @"clock": [UIColor systemYellowColor],
        @"vase": [UIColor systemPurpleColor],
        @"scissors": [UIColor systemGreenColor],
        @"teddy bear": [UIColor systemPinkColor],
        @"hair drier": [UIColor systemGrayColor],
        @"toothbrush": [UIColor systemBlueColor]
    };

    
    data = loadBytesFromFile(@"load_and_inf");
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
    NSArray *ops = @[@"BufferAlloc", @"CopyIn", @"ProgramAlloc"];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"(%@)\\(", [ops componentsJoinedByString:@"|"]] options:0 error:nil];
    __block NSInteger lastIndex = 0;
    [regex enumerateMatchesInString:string_data options:0 range:NSMakeRange(0, string_data.length) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        [_q addObject:extractValues([[string_data substringWithRange:NSMakeRange(lastIndex, match.range.location - lastIndex)] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]])];
        lastIndex = match.range.location;
    }];
    [_q addObject:extractValues([[string_data substringFromIndex:lastIndex] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]])];
    for (NSMutableDictionary *values in _q) {
        if ([values[@"op"] isEqualToString:@"BufferAlloc"]) {
            [buffers setObject:[device newBufferWithLength:[values[@"size"][0] intValue] options:MTLResourceStorageModeShared] forKey:values[@"buffer_num"][0]];
        } else if ([values[@"op"] isEqualToString:@"CopyIn"]) {
            id<MTLBuffer> buffer = buffers[values[@"buffer_num"][0]];
            NSData *data = _h[values[@"datahash"][0]];
            memcpy(buffer.contents, data.bytes, data.length);
        } else if ([values[@"op"] isEqualToString:@"ProgramAlloc"]) {
            if ([pipeline_states objectForKey:@[values[@"name"][0],values[@"datahash"][0]]]) continue;
            NSString *prg = [[NSString alloc] initWithData:_h[values[@"datahash"][0]] encoding:NSUTF8StringEncoding];
            NSError *error = nil;
            id<MTLLibrary> library = [device newLibraryWithSource:prg
                                                          options:nil
                                                            error:&error];
            MTLComputePipelineDescriptor *descriptor = [[MTLComputePipelineDescriptor alloc] init];
            descriptor.computeFunction = [library newFunctionWithName:values[@"name"][0]];;
            descriptor.supportIndirectCommandBuffers = YES;
            MTLComputePipelineReflection *reflection = nil;
            id<MTLComputePipelineState> pipeline_state = [device newComputePipelineStateWithDescriptor:descriptor
                                                                                               options:MTLPipelineOptionNone
                                                                                            reflection:&reflection
                                                                                                 error:&error];
            [pipeline_states setObject:pipeline_state forKey:@[values[@"name"][0],values[@"datahash"][0]]];
        }
    }
    data = loadBytesFromFile(@"load_and_inf"); //todo, use same file, one load?
    
    bytes = CFDataGetBytePtr(data);
    length = CFDataGetLength(data);

    _h = [[NSMutableDictionary alloc] init];
    ptr = 0;
    datahash = [NSMutableString stringWithCapacity:0x40];
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
    string_data = [[NSString alloc] initWithData:range_data encoding:NSUTF8StringEncoding];
    _q = [NSMutableArray array];
    ops = @[@"ProgramExec"];
    regex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"(%@)\\(", [ops componentsJoinedByString:@"|"]] options:0 error:nil];
    lastIndex = 0;
    [regex enumerateMatchesInString:string_data options:0 range:NSMakeRange(0, string_data.length) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        [_q addObject:extractValues([[string_data substringWithRange:NSMakeRange(lastIndex, match.range.location - lastIndex)] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]])];
        lastIndex = match.range.location;
    }];
    [_q addObject:extractValues([[string_data substringFromIndex:lastIndex] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]])];
    
    // Set up the UI
    [self setupUI];
    
    // Start the camera session
    [self setupCamera];
}

#pragma mark - Setup UI
- (void)setupUI {
    // Calculate the size and position for a square view
    CGFloat squareSize = MIN(self.view.bounds.size.width, self.view.bounds.size.height);
    CGFloat xOffset = (self.view.bounds.size.width - squareSize) / 2.0;
    CGFloat yOffset = (self.view.bounds.size.height - squareSize) / 2.0;

    // Create a square UIImageView for the camera feed
    self.imageView = [[UIImageView alloc] initWithFrame:CGRectMake(xOffset, yOffset, squareSize, squareSize)];
    self.imageView.contentMode = UIViewContentModeScaleAspectFill; // Preserve aspect ratio
    self.imageView.clipsToBounds = YES; // Clip to square boundaries
    [self.view addSubview:self.imageView];
    
    // Create an FPS label
    self.fpsLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 50, 150, 30)];
    self.fpsLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    self.fpsLabel.textColor = [UIColor whiteColor];
    self.fpsLabel.font = [UIFont boldSystemFontOfSize:18];
    self.fpsLabel.text = @"FPS: 0";
    [self.view addSubview:self.fpsLabel];
}

NSArray *processOutput(const float *output, int outputLength, float imgWidth, float imgHeight) {
    NSMutableArray *boxes = [NSMutableArray array];
    int modelInputSize = 416; // Replace this with your actual model input size
    int numPredictions = pow(modelInputSize / 32, 2) * 21;

    for (int index = 0; index < numPredictions; index++) {
        int classId = 0;
        float prob = 0.0;

        for (int col = 0; col < 80; col++) {
            float confidence = output[numPredictions * (col + 4) + index];
            if (confidence > prob) {
                prob = confidence;
                classId = col;
            }
        }

        if (prob < 0.25) continue;

        NSString *label = yolo_classes[classId];
        float xc = output[index];
        float yc = output[numPredictions + index];
        float w = output[2 * numPredictions + index];
        float h = output[3 * numPredictions + index];

        float x1 = (xc - w / 2) / modelInputSize * imgWidth;
        float y1 = (yc - h / 2) / modelInputSize * imgHeight;
        float x2 = (xc + w / 2) / modelInputSize * imgWidth;
        float y2 = (yc + h / 2) / modelInputSize * imgHeight;

        [boxes addObject:@[@(x1), @(y1), @(x2), @(y2), label, @(prob)]];
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
            if (iouBetweenBox(bestBox, box) < 0.7) {
                [filteredBoxes addObject:box];
            }
        }
        boxes = filteredBoxes;
    }

    return [result copy];
}

CGFloat iouBetweenBox(NSArray *box1, NSArray *box2) {
    return intersectionBetweenBox(box1, box2) / unionBetweenBox(box1, box2);
}

UIImage *drawSquareOnImage(UIImage *image, CGFloat xOrigin, CGFloat yOrigin, CGFloat bottomLeftX, CGFloat bottomLeftY, NSString *className) {
    CGFloat width = bottomLeftX - xOrigin;
    CGFloat height = bottomLeftY - yOrigin;
    UIGraphicsBeginImageContext(image.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    [image drawAtPoint:CGPointZero];

    UIColor *color = classColorMap[className] ?: [UIColor blackColor]; // Default to black if class not found
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, 2.0);

    CGRect squareRect = CGRectMake(xOrigin, yOrigin, width, height);
    CGContextAddRect(context, squareRect);
    CGContextStrokePath(context);

    NSDictionary *textAttributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:12],
        NSForegroundColorAttributeName: [UIColor whiteColor]
    };

    NSString *labelText = [className lowercaseString];
    CGSize textSize = [labelText sizeWithAttributes:textAttributes];

    CGRect textBackgroundRect = CGRectMake(xOrigin, yOrigin, textSize.width + 4, textSize.height + 2); // Add padding
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, textBackgroundRect);

    [labelText drawAtPoint:CGPointMake(xOrigin + 2, yOrigin + 1) withAttributes:textAttributes]; // Adjust for padding

    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return newImage;
}

CGFloat unionBetweenBox(NSArray *box1, NSArray *box2) {
    CGFloat box1X1 = [box1[0] floatValue];
    CGFloat box1Y1 = [box1[1] floatValue];
    CGFloat box1X2 = [box1[2] floatValue];
    CGFloat box1Y2 = [box1[3] floatValue];
    CGFloat box2X1 = [box2[0] floatValue];
    CGFloat box2Y1 = [box2[1] floatValue];
    CGFloat box2X2 = [box2[2] floatValue];
    CGFloat box2Y2 = [box2[3] floatValue];

    CGFloat box1Area = (box1X2 - box1X1) * (box1Y2 - box1Y1);
    CGFloat box2Area = (box2X2 - box2X1) * (box2Y2 - box2Y1);

    return box1Area + box2Area - intersectionBetweenBox(box1, box2);
}

CGFloat intersectionBetweenBox(NSArray *box1, NSArray *box2) {
    CGFloat box1X1 = [box1[0] floatValue];
    CGFloat box1Y1 = [box1[1] floatValue];
    CGFloat box1X2 = [box1[2] floatValue];
    CGFloat box1Y2 = [box1[3] floatValue];
    CGFloat box2X1 = [box2[0] floatValue];
    CGFloat box2Y1 = [box2[1] floatValue];
    CGFloat box2X2 = [box2[2] floatValue];
    CGFloat box2Y2 = [box2[3] floatValue];

    CGFloat x1 = MAX(box1X1, box2X1);
    CGFloat y1 = MAX(box1Y1, box2Y1);
    CGFloat x2 = MIN(box1X2, box2X2);
    CGFloat y2 = MIN(box1Y2, box2Y2);

    CGFloat intersectionWidth = MAX(0, x2 - x1);
    CGFloat intersectionHeight = MAX(0, y2 - y1);

    return intersectionWidth * intersectionHeight;
}


CFDataRef loadBytesFromFile(NSString *fileName) {
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:fileName];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    if (!data) {
        NSLog(@"Failed to load file at path: %@", filePath);
        return NULL;
    }
    return CFDataCreate(NULL, [data bytes], [data length]);
}

NSMutableDictionary<NSString *, id> *extractValues(NSString *x) {
    NSMutableDictionary<NSString *, id> *values = [@{@"op": [x componentsSeparatedByString:@"("][0]} mutableCopy];
    NSDictionary<NSString *, NSString *> *patterns = @{@"name": @"name='([^']+)'",@"datahash": @"datahash='([^']+)'",@"global_sizes": @"global_size=\\(([^)]+)\\)",
        @"local_sizes": @"local_size=\\(([^)]+)\\)",@"wait": @"wait=(True|False)",@"bufs": @"bufs=\\(([^)]+)\\)",@"vals": @"vals=\\(([^)]+)\\)",
        @"buffer_num": @"buffer_num=(\\d+)",@"size": @"size=(\\d+)"};
    [patterns enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *pattern, BOOL *stop) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:x options:0 range:NSMakeRange(0, x.length)];
        if (match) {
            NSString *contents = [x substringWithRange:[match rangeAtIndex:1]];
            NSMutableArray<NSString *> *extracted_values = [NSMutableArray array];
            for (NSString *value in [contents componentsSeparatedByString:@","]) {
                NSString *trimmed_value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (trimmed_value.length > 0) {
                    [extracted_values addObject:trimmed_value];
                }
            }
            values[key] = [extracted_values copy];
        }
    }];
    return values;
}

#pragma mark - Setup Camera
- (void)setupCamera {
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPreset640x480; // Adjust resolution as needed

    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        NSLog(@"Error accessing camera: %@", error.localizedDescription);
        return;
    }
    [self.session addInput:input];

    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [output setAlwaysDiscardsLateVideoFrames:YES]; // Improve performance
    dispatch_queue_t queue = dispatch_queue_create("VideoQueue", DISPATCH_QUEUE_SERIAL);
    [output setSampleBufferDelegate:self queue:queue];
    [self.session addOutput:output];
    
    // Ensure proper orientation
    AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
    if ([connection isVideoOrientationSupported]) {
        connection.videoOrientation = AVCaptureVideoOrientationPortrait; // Set orientation to portrait
    }
    [self.session startRunning];
}

#pragma mark - Process Frames
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    @autoreleasepool {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];

        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);

        CGFloat cropSize = MIN(width, height);
        CGRect cropRect = CGRectMake((width - cropSize) / 2.0, (height - cropSize) / 2.0, cropSize, cropSize);
        CIImage *croppedImage = [ciImage imageByCroppingToRect:cropRect];

        CGSize targetSize = CGSizeMake(416, 416);
        CGFloat scaleX = targetSize.width / cropSize;
        CGFloat scaleY = targetSize.height / cropSize;
        CIImage *resizedImage = [croppedImage imageByApplyingTransform:CGAffineTransformMakeScale(scaleX, scaleY)];

        CIContext *context = [CIContext context];
        CGImageRef cgImage = [context createCGImage:resizedImage fromRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
        UIImage *uiImage = [UIImage imageWithCGImage:cgImage];
        
        CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
        const UInt8 *rawBytes = CFDataGetBytePtr(rawData);
        size_t length = CFDataGetLength(rawData);
        size_t rgbLength = (length / 4) * 3;
        UInt8 *rgbData = (UInt8 *)malloc(rgbLength);
        
        for (size_t i = 0, j = 0; i < length; i += 4, j += 3) {
            rgbData[j] = rawBytes[i];         // Red
            rgbData[j + 1] = rawBytes[i + 1]; // Green
            rgbData[j + 2] = rawBytes[i + 2]; // Blue
        }
        id<MTLBuffer> buffer = buffers[@"359"];
        memcpy(buffer.contents, rgbData, rgbLength);
        free(rgbData);
        CFRelease(rawData);
        
        for (NSMutableDictionary *values in _q) {
            if ([values[@"op"] isEqualToString:@"ProgramExec"]) {
                id<MTLCommandBuffer> command_buffer = [mtl_queue commandBuffer];
                id<MTLComputeCommandEncoder> encoder = [command_buffer computeCommandEncoder];
                [encoder setComputePipelineState:pipeline_states[@[values[@"name"][0],values[@"datahash"][0]]]];
                for(int i = 0; i < [(NSArray *)values[@"bufs"] count]; i++){
                    [encoder setBuffer:buffers[values[@"bufs"][i]] offset:0 atIndex:i];
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
                [mtl_buffers_in_flight addObject: command_buffer];
            }
        }
        
        //todo put this in copyout or ?
        for(int i = 0; i < mtl_buffers_in_flight.count; i++){
            [mtl_buffers_in_flight[i] waitUntilCompleted];
        }
        [mtl_buffers_in_flight removeAllObjects];
        buffer = buffers[@"636"];
        const void *bufferPointer = buffer.contents;
        float *floatArray = malloc(buffer.length);
        memcpy(floatArray, bufferPointer, buffer.length);
        NSArray *output = processOutput(floatArray,buffer.length / 4,416,416);
        for(int i = 0; i < output.count; i++){
            uiImage = drawSquareOnImage(uiImage, [output[i][0] floatValue], [output[i][1] floatValue], [output[i][2] floatValue], [output[i][3] floatValue],output[i][4    ]);
        }
        free(floatArray);
        //exit(0);

        CGImageRelease(cgImage);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.imageView.image = uiImage;
            [self updatePixelArrayWithImage:uiImage];
            [self updateFPS];
        });
    }
}

#pragma mark - Update Pixel Array
- (void)updatePixelArrayWithImage:(UIImage *)image {
    CGImageRef cgImage = image.CGImage;
    NSUInteger width = CGImageGetWidth(cgImage);
    NSUInteger height = CGImageGetHeight(cgImage);
    NSUInteger bytesPerPixel = 4; // RGBA
    NSUInteger bytesPerRow = bytesPerPixel * width;
    self.totalBytes = bytesPerRow * height;

    // Allocate buffer if necessary
    if (self.pixelArray == NULL) {
        self.pixelArray = malloc(self.totalBytes);
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(self.pixelArray, width, height, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(context);
}

#pragma mark - Update FPS
- (void)updateFPS {
    CFTimeInterval currentTime = CACurrentMediaTime();
    if (self.lastFrameTime > 0) {
        CFTimeInterval deltaTime = currentTime - self.lastFrameTime;
        self.frameCount++;
        if (self.frameCount >= 10) { // Update FPS every 10 frames
            CGFloat fps = 10.0 / deltaTime;
            self.fpsLabel.text = [NSString stringWithFormat:@"FPS: %.1f", fps];
            self.frameCount = 0;
            self.lastFrameTime = currentTime;
        }
    } else {
        self.lastFrameTime = currentTime;
    }
}

#pragma mark - Clean Up
- (void)dealloc {
    [self.session stopRunning];
    if (self.pixelArray) {
        free(self.pixelArray);
    }
}
@end
