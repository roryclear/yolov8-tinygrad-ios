#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Yolo : NSObject

// Initializer
- (instancetype)init;

// Methods for Intersection over Union (IoU)
- (CGFloat)intersectionBetweenBox:(NSArray *)box1 andBox:(NSArray *)box2;
- (CGFloat)unionBetweenBox:(NSArray *)box1 andBox:(NSArray *)box2;
- (CGFloat)iouBetweenBox:(NSArray *)box1 andBox:(NSArray *)box2;

// Method to extract values from a string
- (NSMutableDictionary<NSString *, id> *)extractValues:(NSString *)x;

@end

NS_ASSUME_NONNULL_END
