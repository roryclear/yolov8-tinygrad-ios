#import "Yolo.h"
#import <Metal/Metal.h>
#import <UIKit/UIKit.h>

@implementation Yolo

id<MTLDevice> device;
NSMutableDictionary<NSString *, id> *pipeline_states;
NSMutableDictionary<NSString *, id> *buffers;
id<MTLCommandQueue> mtl_queue;
NSMutableArray<id<MTLCommandBuffer>> *mtl_buffers_in_flight;
int yolo_res;
NSArray *yolo_classes;
CFDataRef data;
NSMutableDictionary *_h;
NSMutableArray *_q;
NSString *input_buffer;
NSString *output_buffer;

- (instancetype)init {
    self = [super init];
    self.device = MTLCreateSystemDefaultDevice();
    self.pipeline_states = [[NSMutableDictionary alloc] init];
    self.buffers = [[NSMutableDictionary alloc] init];
    self.mtl_queue = [self.device newCommandQueueWithMaxCommandBufferCount:1024];
    self.mtl_buffers_in_flight = [[NSMutableArray alloc] init];
    self.yolo_res = 640;
    self.yolo_classes = @[
        @[@"person", [UIColor redColor]],@[@"bicycle", [UIColor greenColor]],@[@"car", [UIColor blueColor]],
        @[@"motorcycle", [UIColor cyanColor]],@[@"airplane", [UIColor magentaColor]],@[@"bus", [UIColor yellowColor]],
        @[@"train", [UIColor orangeColor]],@[@"truck", [UIColor purpleColor]],@[@"boat", [UIColor brownColor]],
        @[@"traffic light", [UIColor colorWithRed:0.5 green:0.7 blue:0.2 alpha:1.0]],@[@"fire hydrant", [UIColor colorWithRed:0.8 green:0.1 blue:0.1 alpha:1.0]],
        @[@"stop sign", [UIColor colorWithRed:0.3 green:0.3 blue:0.8 alpha:1.0]],@[@"parking meter", [UIColor colorWithRed:0.7 green:0.5 blue:0.3 alpha:1.0]],
        @[@"bench", [UIColor colorWithRed:0.4 green:0.4 blue:0.2 alpha:1.0]],@[@"bird", [UIColor colorWithRed:0.1 green:0.5 blue:0.9 alpha:1.0]],
        @[@"cat", [UIColor colorWithRed:0.8 green:0.2 blue:0.6 alpha:1.0]],@[@"dog", [UIColor colorWithRed:0.9 green:0.3 blue:0.3 alpha:1.0]],
        @[@"horse", [UIColor colorWithRed:0.2 green:0.6 blue:0.7 alpha:1.0]],@[@"sheep", [UIColor colorWithRed:0.7 green:0.3 blue:0.5 alpha:1.0]],
        @[@"cow", [UIColor colorWithRed:0.4 green:0.8 blue:0.4 alpha:1.0]],@[@"elephant", [UIColor colorWithRed:0.3 green:0.4 blue:0.9 alpha:1.0]],
        @[@"bear", [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:1.0]],@[@"zebra", [UIColor colorWithRed:0.8 green:0.5 blue:0.2 alpha:1.0]],
        @[@"giraffe", [UIColor colorWithRed:0.5 green:0.9 blue:0.1 alpha:1.0]],@[@"backpack", [UIColor colorWithRed:0.3 green:0.7 blue:0.4 alpha:1.0]],
        @[@"umbrella", [UIColor colorWithRed:0.4 green:0.6 blue:0.9 alpha:1.0]],@[@"handbag", [UIColor colorWithRed:0.9 green:0.2 blue:0.5 alpha:1.0]],
        @[@"tie", [UIColor colorWithRed:0.5 green:0.3 blue:0.7 alpha:1.0]],@[@"suitcase", [UIColor colorWithRed:0.6 green:0.7 blue:0.2 alpha:1.0]],
        @[@"frisbee", [UIColor colorWithRed:0.7 green:0.2 blue:0.4 alpha:1.0]],@[@"skis", [UIColor colorWithRed:0.3 green:0.9 blue:0.3 alpha:1.0]],
        @[@"snowboard", [UIColor colorWithRed:0.8 green:0.1 blue:0.6 alpha:1.0]],@[@"sports ball", [UIColor colorWithRed:0.4 green:0.3 blue:0.8 alpha:1.0]],
        @[@"kite", [UIColor colorWithRed:0.2 green:0.5 blue:0.7 alpha:1.0]],@[@"baseball bat", [UIColor colorWithRed:0.6 green:0.4 blue:0.2 alpha:1.0]],
        @[@"baseball glove", [UIColor colorWithRed:0.7 green:0.1 blue:0.4 alpha:1.0]],@[@"skateboard", [UIColor colorWithRed:0.5 green:0.8 blue:0.5 alpha:1.0]],
        @[@"surfboard", [UIColor colorWithRed:0.8 green:0.3 blue:0.6 alpha:1.0]],@[@"tennis racket", [UIColor colorWithRed:0.2 green:0.7 blue:0.9 alpha:1.0]],
        @[@"bottle", [UIColor colorWithRed:0.9 green:0.2 blue:0.3 alpha:1.0]],@[@"wine glass", [UIColor colorWithRed:0.6 green:0.6 blue:0.3 alpha:1.0]],
        @[@"cup", [UIColor colorWithRed:0.3 green:0.4 blue:0.9 alpha:1.0]],@[@"fork", [UIColor colorWithRed:0.4 green:0.7 blue:0.2 alpha:1.0]],
        @[@"knife", [UIColor colorWithRed:0.8 green:0.2 blue:0.5 alpha:1.0]],@[@"spoon", [UIColor colorWithRed:0.6 green:0.3 blue:0.7 alpha:1.0]],
        @[@"bowl", [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0]],@[@"banana", [UIColor colorWithRed:0.7 green:0.7 blue:0.1 alpha:1.0]],
        @[@"apple", [UIColor colorWithRed:0.9 green:0.1 blue:0.4 alpha:1.0]],@[@"sandwich", [UIColor colorWithRed:0.4 green:0.5 blue:0.8 alpha:1.0]],
        @[@"orange", [UIColor colorWithRed:0.8 green:0.6 blue:0.2 alpha:1.0]],@[@"broccoli", [UIColor colorWithRed:0.3 green:0.8 blue:0.3 alpha:1.0]],
        @[@"carrot", [UIColor colorWithRed:0.7 green:0.2 blue:0.6 alpha:1.0]],@[@"hot dog", [UIColor colorWithRed:0.9 green:0.3 blue:0.5 alpha:1.0]],
        @[@"pizza", [UIColor colorWithRed:0.5 green:0.3 blue:0.8 alpha:1.0]],@[@"donut", [UIColor colorWithRed:0.8 green:0.1 blue:0.4 alpha:1.0]],
        @[@"cake", [UIColor colorWithRed:0.7 green:0.5 blue:0.1 alpha:1.0]],@[@"chair", [UIColor colorWithRed:0.6 green:0.2 blue:0.4 alpha:1.0]],
        @[@"couch", [UIColor colorWithRed:0.4 green:0.6 blue:0.2 alpha:1.0]],@[@"potted plant", [UIColor colorWithRed:0.8 green:0.4 blue:0.5 alpha:1.0]],
        @[@"bed", [UIColor colorWithRed:0.3 green:0.7 blue:0.7 alpha:1.0]],@[@"dining table", [UIColor colorWithRed:0.5 green:0.8 blue:0.3 alpha:1.0]],
        @[@"toilet", [UIColor colorWithRed:0.7 green:0.4 blue:0.6 alpha:1.0]],@[@"tv", [UIColor colorWithRed:0.9 green:0.5 blue:0.2 alpha:1.0]],
        @[@"laptop", [UIColor colorWithRed:0.6 green:0.3 blue:0.7 alpha:1.0]],@[@"mouse", [UIColor colorWithRed:0.2 green:0.9 blue:0.5 alpha:1.0]],
        @[@"remote", [UIColor colorWithRed:0.8 green:0.4 blue:0.3 alpha:1.0]],@[@"keyboard", [UIColor colorWithRed:0.3 green:0.6 blue:0.8 alpha:1.0]],
        @[@"cell phone", [UIColor colorWithRed:0.7 green:0.3 blue:0.9 alpha:1.0]],@[@"microwave", [UIColor colorWithRed:0.4 green:0.9 blue:0.4 alpha:1.0]],
        @[@"oven", [UIColor colorWithRed:0.5 green:0.7 blue:0.2 alpha:1.0]],@[@"toaster", [UIColor colorWithRed:0.9 green:0.2 blue:0.3 alpha:1.0]],
        @[@"sink", [UIColor colorWithRed:0.6 green:0.8 blue:0.3 alpha:1.0]],@[@"refrigerator", [UIColor colorWithRed:0.8 green:0.4 blue:0.7 alpha:1.0]],
        @[@"book", [UIColor colorWithRed:0.3 green:0.5 blue:0.9 alpha:1.0]],@[@"clock", [UIColor colorWithRed:0.7 green:0.7 blue:0.2 alpha:1.0]],
        @[@"vase", [UIColor colorWithRed:0.9 green:0.4 blue:0.5 alpha:1.0]],@[@"scissors", [UIColor colorWithRed:0.2 green:0.7 blue:0.8 alpha:1.0]],
        @[@"teddy bear", [UIColor colorWithRed:0.6 green:0.3 blue:0.9 alpha:1.0]],@[@"hair drier", [UIColor colorWithRed:0.8 green:0.2 blue:0.3 alpha:1.0]],
        @[@"toothbrush", [UIColor colorWithRed:0.4 green:0.7 blue:0.6 alpha:1.0]]
    ];
    
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:[NSString stringWithFormat:@"batch_req_%dx%d", self.yolo_res, self.yolo_res]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://raw.githubusercontent.com/roryclear/yolov8-tinygrad-ios/main/batch_req_%dx%d",self.yolo_res,self.yolo_res]]];
        [data writeToFile:filePath atomically:YES];
    }
    NSData *ns_data = [NSData dataWithContentsOfFile:filePath];
    self.data = CFDataCreate(NULL, [ns_data bytes], [ns_data length]);
    
    return self;
}

// Calculate intersection between two boxes
- (CGFloat)intersectionBetweenBox:(NSArray *)box1 andBox:(NSArray *)box2 {
    CGFloat x1 = MAX([box1[0] floatValue], [box2[0] floatValue]);
    CGFloat y1 = MAX([box1[1] floatValue], [box2[1] floatValue]);
    CGFloat x2 = MIN([box1[2] floatValue], [box2[2] floatValue]);
    CGFloat y2 = MIN([box1[3] floatValue], [box2[3] floatValue]);
    return MAX(0, x2 - x1) * MAX(0, y2 - y1);
}

// Calculate union between two boxes
- (CGFloat)unionBetweenBox:(NSArray *)box1 andBox:(NSArray *)box2 {
    CGFloat box1Area = ([box1[2] floatValue] - [box1[0] floatValue]) * ([box1[3] floatValue] - [box1[1] floatValue]);
    CGFloat box2Area = ([box2[2] floatValue] - [box2[0] floatValue]) * ([box2[3] floatValue] - [box2[1] floatValue]);
    return box1Area + box2Area - [self intersectionBetweenBox:box1 andBox:box2];
}

// Calculate Intersection over Union (IoU) between two boxes
- (CGFloat)iouBetweenBox:(NSArray *)box1 andBox:(NSArray *)box2 {
    return [self intersectionBetweenBox:box1 andBox:box2] / [self unionBetweenBox:box1 andBox:box2];
}

// Extract values from a string
- (NSMutableDictionary<NSString *, id> *)extractValues:(NSString *)x {
    NSMutableDictionary<NSString *, id> *values = [@{@"op": [x componentsSeparatedByString:@"("][0]} mutableCopy];
    NSDictionary<NSString *, NSString *> *patterns = @{@"name": @"name='([^']+)'", @"datahash": @"datahash='([^']+)'", @"global_sizes": @"global_size=\\(([^)]+)\\)",
                                                       @"local_sizes": @"local_size=\\(([^)]+)\\)", @"bufs": @"bufs=\\(([^)]+)",
                                                       @"vals": @"vals=\\(([^)]+)", @"buffer_num": @"buffer_num=(\\d+)", @"size": @"size=(\\d+)"};
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

@end

