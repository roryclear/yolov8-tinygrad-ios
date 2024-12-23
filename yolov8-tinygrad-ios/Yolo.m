#import <Foundation/Foundation.h>
#import "Yolo.h"

CGFloat intersectionBetweenBox(NSArray *box1, NSArray *box2) {
    CGFloat x1 = MAX([box1[0] floatValue], [box2[0] floatValue]);
    CGFloat y1 = MAX([box1[1] floatValue], [box2[1] floatValue]);
    CGFloat x2 = MIN([box1[2] floatValue], [box2[2] floatValue]);
    CGFloat y2 = MIN([box1[3] floatValue], [box2[3] floatValue]);
    return MAX(0, x2 - x1) * MAX(0, y2 - y1);
}

CGFloat unionBetweenBox(NSArray *box1, NSArray *box2) {
    CGFloat box1Area = ([box1[2] floatValue] - [box1[0] floatValue]) * ([box1[3] floatValue] - [box1[1] floatValue]);
    CGFloat box2Area = ([box2[2] floatValue] - [box2[0] floatValue]) * ([box2[3] floatValue] - [box2[1] floatValue]);
    return box1Area + box2Area - intersectionBetweenBox(box1, box2);
}

CGFloat iouBetweenBox(NSArray *box1, NSArray *box2) {
    return intersectionBetweenBox(box1, box2) / unionBetweenBox(box1, box2);
}

NSMutableDictionary<NSString *, id> *extractValues(NSString *x) {
    NSMutableDictionary<NSString *, id> *values = [@{@"op": [x componentsSeparatedByString:@"("][0]} mutableCopy];
    NSDictionary<NSString *, NSString *> *patterns = @{@"name": @"name='([^']+)'",@"datahash": @"datahash='([^']+)'",@"global_sizes": @"global_size=\\(([^)]+)\\)",
        @"local_sizes": @"local_size=\\(([^)]+)\\)",@"bufs": @"bufs=\\(([^)]+)\\)",@"vals": @"vals=\\(([^)]+)\\)",
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
